type position = Right | Bottom

type rect = { row : int; col : int; rows : int; cols : int }

type layout = {
  enabled : bool;
  position : position option;
  results : rect;
  preview : rect option;
}

type source_kind =
  | No_selection
  | Candidate_text
  | Regular_file
  | Directory
  | Missing_path
  | Unreadable_path
  | Binary_file
  | Command_output
  | Command_error

type source = File_preview | Command_preview of string

type classification =
  | Regular_file_path of string
  | Directory_path of string
  | Missing_path_value of string
  | Unreadable_path_value of string
  | Plain_text_value of string

type content = {
  kind : source_kind;
  title : string;
  lines : string list;
  truncated : bool;
}

let min_result_rows = 3
let min_preview_rows = 3
let min_result_cols = 20
let min_preview_cols = 20
let max_preview_bytes = 256 * 1024
let preview_command_timeout_ms = 500

let parse_position = function
  | "right" -> Some Right
  | "bottom" -> Some Bottom
  | _ -> None

let position_to_string = function Right -> "right" | Bottom -> "bottom"

let full_results terminal_rows terminal_cols =
  { row = 3; col = 1; rows = max 0 (terminal_rows - 2); cols = max 0 terminal_cols }

let disabled terminal_rows terminal_cols =
  { enabled = false; position = None; results = full_results terminal_rows terminal_cols; preview = None }

let compute_layout ~terminal_rows ~terminal_cols ~preview ~position =
  let terminal_rows = max 0 terminal_rows in
  let terminal_cols = max 0 terminal_cols in
  if (not preview) || terminal_rows <= 2 || terminal_cols <= 0 then disabled terminal_rows terminal_cols
  else
    let body_rows = max 0 (terminal_rows - 2) in
    match position with
    | Right ->
        let preview_cols = terminal_cols / 2 in
        let result_cols = terminal_cols - preview_cols - 1 in
        if body_rows < min_result_rows || result_cols < min_result_cols || preview_cols < min_preview_cols then
          disabled terminal_rows terminal_cols
        else
          {
            enabled = true;
            position = Some Right;
            results = { row = 3; col = 1; rows = body_rows; cols = result_cols };
            preview = Some { row = 3; col = result_cols + 2; rows = body_rows; cols = preview_cols };
          }
    | Bottom ->
        let preview_rows = max min_preview_rows (body_rows / 3) in
        let result_rows = body_rows - preview_rows - 1 in
        if result_rows < min_result_rows || preview_rows < min_preview_rows || terminal_cols < min_preview_cols then
          disabled terminal_rows terminal_cols
        else
          {
            enabled = true;
            position = Some Bottom;
            results = { row = 3; col = 1; rows = result_rows; cols = terminal_cols };
            preview = Some { row = 3 + result_rows + 1; col = 1; rows = preview_rows; cols = terminal_cols };
          }

let contains_char needle value =
  let rec loop index =
    index < String.length value && (value.[index] = needle || loop (index + 1))
  in
  loop 0

let looks_like_path value =
  value <> ""
  && (contains_char '/' value || contains_char '\\' value || contains_char '.' value
     || String.length value >= 2 && String.sub value 0 2 = "~/"
     || String.length value >= 2 && String.sub value 0 2 = "./"
     || String.length value >= 3 && String.sub value 0 3 = "../")

let classify_candidate candidate =
  if candidate = "" then Plain_text_value candidate
  else
    try
      let stat = Unix.stat candidate in
      match stat.Unix.st_kind with
      | Unix.S_REG -> (
          try
            Unix.access candidate [ Unix.R_OK ];
            Regular_file_path candidate
          with Unix.Unix_error _ -> Unreadable_path_value candidate)
      | Unix.S_DIR -> Directory_path candidate
      | Unix.S_CHR | Unix.S_BLK | Unix.S_LNK | Unix.S_FIFO | Unix.S_SOCK ->
          Plain_text_value candidate
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) | Unix.Unix_error (Unix.ENOTDIR, _, _) ->
        if looks_like_path candidate then Missing_path_value candidate else Plain_text_value candidate
    | Unix.Unix_error (Unix.EACCES, _, _) -> Unreadable_path_value candidate
    | Unix.Unix_error _ ->
        if looks_like_path candidate then Missing_path_value candidate else Plain_text_value candidate

let read_file_prefix ~max_bytes path =
  let max_bytes = max 0 max_bytes in
  try
    let channel = open_in_bin path in
    let close () = try close_in_noerr channel with _ -> () in
    match max_bytes with
    | 0 ->
        close ();
        Ok ("", true)
    | _ -> (
        try
          let buffer = Bytes.create (max_bytes + 1) in
          let count = input channel buffer 0 (max_bytes + 1) in
          close ();
          let truncated = count > max_bytes in
          let length = min count max_bytes in
          Ok (Bytes.sub_string buffer 0 length, truncated)
        with exn ->
          close ();
          Error (Printexc.to_string exn))
  with exn -> Error (Printexc.to_string exn)

let is_allowed_control = function '\n' | '\r' | '\t' -> true | _ -> false

let is_binary_looking value =
  let length = String.length value in
  let rec loop index controls =
    if index >= length then controls > max 8 (length / 20)
    else
      let char = value.[index] in
      if char = '\000' then true
      else
        let code = Char.code char in
        let controls =
          if code < 0x20 && not (is_allowed_control char) then controls + 1 else controls
        in
        loop (index + 1) controls
  in
  length > 0 && loop 0 0

let normalize_lines value =
  let normalized =
    value |> String.split_on_char '\n'
    |> List.map (fun line ->
           let length = String.length line in
           if length > 0 && line.[length - 1] = '\r' then String.sub line 0 (length - 1)
           else line)
  in
  match List.rev normalized with
  | "" :: rest -> List.rev rest
  | _ -> normalized

let content_of_candidate_text candidate =
  { kind = Candidate_text; title = "candidate text"; lines = [ candidate ]; truncated = false }

let no_selection_content =
  {
    kind = No_selection;
    title = "no selected result";
    lines = [ "preview: no selected result" ];
    truncated = false;
  }

type captured_stream = {
  text : string;
  truncated : bool;
}

type command_result = {
  status : Unix.process_status;
  stdout : captured_stream;
  stderr : captured_stream;
}

let command_source command = Command_preview command

let source_to_string = function
  | File_preview -> "file"
  | Command_preview command -> "command:" ^ command

let append_capped buffer ~max_bytes ~truncated chunk length =
  if length <= 0 then truncated
  else
    let remaining = max 0 (max_bytes - Buffer.length buffer) in
    let copy_length = min length remaining in
    if copy_length > 0 then Buffer.add_subbytes buffer chunk 0 copy_length;
    truncated || copy_length < length

let read_available fd buffer ~max_bytes ~truncated =
  let chunk = Bytes.create 4096 in
  let rec loop truncated =
    try
      match Unix.read fd chunk 0 (Bytes.length chunk) with
      | 0 -> `Closed truncated
      | count -> loop (append_capped buffer ~max_bytes ~truncated chunk count)
    with
    | Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) -> `Open truncated
    | Unix.Unix_error (Unix.EINTR, _, _) -> loop truncated
  in
  loop truncated

let close_fd fd = try Unix.close fd with Unix.Unix_error _ -> ()

let waitpid_noerr pid =
  try ignore (Unix.waitpid [] pid) with Unix.Unix_error _ -> ()

let executable_access path =
  try
    let stat = Unix.stat path in
    if stat.Unix.st_kind = Unix.S_DIR then Error Unix.EACCES
    else (
      Unix.access path [ Unix.X_OK ];
      Ok path)
  with Unix.Unix_error (error, _, _) -> Error error

let split_path value =
  value |> String.split_on_char ':' |> List.filter (fun entry -> entry <> "")

let resolve_command command =
  if command = "" then Error Unix.ENOENT
  else if contains_char '/' command then executable_access command
  else
    let paths =
      match Sys.getenv_opt "PATH" with
      | None | Some "" -> [ "/bin"; "/usr/bin" ]
      | Some value -> split_path value
    in
    let rec loop = function
      | [] -> Error Unix.ENOENT
      | dir :: rest -> (
          let path = Filename.concat dir command in
          match executable_access path with Ok _ as ok -> ok | Error _ -> loop rest)
    in
    loop paths

let run_command ~timeout_ms ~max_bytes command candidate =
  let max_bytes = max 0 max_bytes in
  match resolve_command command with
  | Error error -> Error error
  | Ok executable ->
  let stdin_fd = Unix.openfile "/dev/null" [ Unix.O_RDONLY ] 0 in
  let stdout_read, stdout_write = Unix.pipe () in
  let stderr_read, stderr_write = Unix.pipe () in
  Fun.protect
    ~finally:(fun () ->
      List.iter close_fd [ stdin_fd; stdout_read; stdout_write; stderr_read; stderr_write ])
    (fun () ->
      Unix.set_nonblock stdout_read;
      Unix.set_nonblock stderr_read;
      let argv = [| command; candidate |] in
      match
        try Ok (Unix.create_process executable argv stdin_fd stdout_write stderr_write)
        with Unix.Unix_error (error, _, _) -> Error error
      with
      | Error error -> Error error
      | Ok pid ->
          close_fd stdout_write;
          close_fd stderr_write;
          let stdout_buffer = Buffer.create (min max_bytes 4096) in
          let stderr_buffer = Buffer.create (min max_bytes 4096) in
          let stdout_open = ref true in
          let stderr_open = ref true in
          let stdout_truncated = ref false in
          let stderr_truncated = ref false in
          let deadline = Unix.gettimeofday () +. (float_of_int timeout_ms /. 1000.0) in
          let poll_status () =
            try
              match Unix.waitpid [ Unix.WNOHANG ] pid with
              | 0, _ -> None
              | _, status -> Some status
            with Unix.Unix_error (Unix.ECHILD, _, _) -> Some (Unix.WEXITED 0)
          in
          let drain_if_ready fd_ref fd buffer truncated =
            if !fd_ref then
              match read_available fd buffer ~max_bytes ~truncated:!truncated with
              | `Open value -> truncated := value
              | `Closed value ->
                  truncated := value;
                  fd_ref := false
          in
          let rec loop status =
            drain_if_ready stdout_open stdout_read stdout_buffer stdout_truncated;
            drain_if_ready stderr_open stderr_read stderr_buffer stderr_truncated;
            match status with
            | Some status when (not !stdout_open) && not !stderr_open ->
                Ok
                  {
                    status;
                    stdout = { text = Buffer.contents stdout_buffer; truncated = !stdout_truncated };
                    stderr = { text = Buffer.contents stderr_buffer; truncated = !stderr_truncated };
                  }
            | _ -> (
                let status = match status with Some _ -> status | None -> poll_status () in
                let remaining = deadline -. Unix.gettimeofday () in
                if remaining <= 0.0 then (
                  (match status with
                  | Some _ -> ()
                  | None ->
                      (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ());
                      waitpid_noerr pid);
                  Error Unix.ETIMEDOUT)
                else
                  let read_fds =
                    (if !stdout_open then [ stdout_read ] else [])
                    @ if !stderr_open then [ stderr_read ] else []
                  in
                  if read_fds = [] then loop (poll_status ())
                  else (
                    ignore (Unix.select read_fds [] [] (min 0.05 remaining));
                    loop status))
          in
          loop None)

let content_lines_for_stream stream = normalize_lines stream.text

let with_truncation_notice stream lines =
  if stream.truncated then lines @ [ "[preview command output truncated]" ] else lines

let empty_command_output_content =
  {
    kind = Command_output;
    title = "command output";
    lines = [ "[preview command produced no output]" ];
    truncated = false;
  }

let content_for_command_success result =
  if result.stdout.text <> "" then
    {
      kind = Command_output;
      title = "command output";
      lines = with_truncation_notice result.stdout (content_lines_for_stream result.stdout);
      truncated = result.stdout.truncated;
    }
  else if result.stderr.text <> "" then
    {
      kind = Command_output;
      title = "command stderr";
      lines =
        with_truncation_notice result.stderr
          ("[preview command wrote stderr]" :: content_lines_for_stream result.stderr);
      truncated = result.stderr.truncated;
    }
  else empty_command_output_content

let process_status_message = function
  | Unix.WEXITED code -> Printf.sprintf "preview command exited with status %d" code
  | Unix.WSIGNALED signal -> Printf.sprintf "preview command killed by signal %d" signal
  | Unix.WSTOPPED signal -> Printf.sprintf "preview command stopped by signal %d" signal

let content_for_command_failure result =
  let stream = if result.stderr.text <> "" then result.stderr else result.stdout in
  let lines =
    match stream.text with
    | "" -> [ process_status_message result.status ]
    | _ -> process_status_message result.status :: content_lines_for_stream stream
  in
  {
    kind = Command_error;
    title = "command failed";
    lines = with_truncation_notice stream lines;
    truncated = stream.truncated;
  }

let content_for_command_error command = function
  | Unix.ENOENT ->
      {
        kind = Command_error;
        title = "command not found";
        lines = [ Printf.sprintf "[preview command not found: %s]" command ];
        truncated = false;
      }
  | Unix.ETIMEDOUT ->
      {
        kind = Command_error;
        title = "command timed out";
        lines =
          [ Printf.sprintf "[preview command timed out after %d ms]" preview_command_timeout_ms ];
        truncated = false;
      }
  | error ->
      {
        kind = Command_error;
        title = "command could not start";
        lines =
          [ Printf.sprintf "[preview command could not start: %s: %s]" command (Unix.error_message error) ];
        truncated = false;
      }

let content_for_command ~max_bytes command selected_candidate =
  match selected_candidate with
  | None -> no_selection_content
  | Some candidate -> (
      match run_command ~timeout_ms:preview_command_timeout_ms ~max_bytes command candidate with
      | Error error -> content_for_command_error command error
      | Ok result -> (
          match result.status with
          | Unix.WEXITED 0 -> content_for_command_success result
          | _ -> content_for_command_failure result))

let content_for_file_selection ~max_bytes = function
  | None -> no_selection_content
  | Some candidate -> (
      match classify_candidate candidate with
      | Plain_text_value value -> content_of_candidate_text value
      | Directory_path path ->
          { kind = Directory; title = "directory"; lines = [ path; "is a directory" ]; truncated = false }
      | Missing_path_value path ->
          {
            kind = Missing_path;
            title = "missing path";
            lines = [ path; "path does not exist" ];
            truncated = false;
          }
      | Unreadable_path_value path ->
          {
            kind = Unreadable_path;
            title = "unreadable file";
            lines = [ path; "file cannot be read" ];
            truncated = false;
          }
      | Regular_file_path path -> (
          match read_file_prefix ~max_bytes path with
          | Error _ ->
              {
                kind = Unreadable_path;
                title = "unreadable file";
                lines = [ path; "file cannot be read" ];
                truncated = false;
              }
          | Ok (data, truncated) ->
              if is_binary_looking data then
                {
                  kind = Binary_file;
                  title = "binary file";
                  lines = [ path; "binary-looking content omitted" ];
                  truncated = false;
                }
              else
                let lines = normalize_lines data in
                {
                  kind = Regular_file;
                  title = path;
                  lines = (if lines = [] then [ "(empty file)" ] else lines);
                  truncated;
                }))

let content_for_selection ?(source = File_preview) ~max_bytes selected =
  match source with
  | File_preview -> content_for_file_selection ~max_bytes selected
  | Command_preview command -> content_for_command ~max_bytes command selected

let content_line_count content = List.length content.lines

let clamp_scroll ~scroll ~line_count ~visible_rows =
  if line_count <= 0 || visible_rows <= 0 then 0
  else min (max 0 scroll) (max 0 (line_count - visible_rows))

let scroll_by ~scroll ~delta ~line_count ~visible_rows =
  clamp_scroll ~scroll:(scroll + delta) ~line_count ~visible_rows

let scroll_status ~scroll ~visible_rows ~line_count =
  if line_count <= 0 || visible_rows <= 0 || line_count <= visible_rows then ""
  else
    let first = clamp_scroll ~scroll ~line_count ~visible_rows + 1 in
    let last = min line_count (first + visible_rows - 1) in
    Printf.sprintf " %d-%d/%d" first last line_count

let kind_to_string = function
  | No_selection -> "empty"
  | Candidate_text -> "text"
  | Regular_file -> "file"
  | Directory -> "directory"
  | Missing_path -> "missing"
  | Unreadable_path -> "unreadable"
  | Binary_file -> "binary"
  | Command_output -> "command"
  | Command_error -> "command-error"

let format_title ~scroll ~visible_rows content =
  Printf.sprintf "preview: %s: %s%s" (kind_to_string content.kind) content.title
    (scroll_status ~scroll ~visible_rows ~line_count:(content_line_count content))

let slice_lines ~start ~count lines =
  let stop = start + max 0 count in
  let rec loop index acc = function
    | [] -> List.rev acc
    | _ when index >= stop -> List.rev acc
    | line :: rest when index >= start -> loop (index + 1) (line :: acc) rest
    | _ :: rest -> loop (index + 1) acc rest
  in
  loop 0 [] lines

let render_content_lines ~terminal_width ~height ~scroll content =
  if height <= 0 then []
  else
    let terminal_width = max 0 terminal_width in
    let content_rows = max 0 (height - 1) in
    let line_count = content_line_count content in
    let scroll = clamp_scroll ~scroll ~line_count ~visible_rows:content_rows in
    let title = Text_width.clip ~width:terminal_width (format_title ~scroll ~visible_rows:content_rows content) in
    let body =
      slice_lines ~start:scroll ~count:content_rows content.lines
      |> List.map (fun line -> Text_width.clip ~width:terminal_width line)
    in
    let rec take_fill remaining acc rows =
      if remaining <= 0 then List.rev acc
      else
        match rows with
        | line :: rest -> take_fill (remaining - 1) (line :: acc) rest
        | [] -> take_fill (remaining - 1) ("" :: acc) []
    in
    title :: take_fill content_rows [] body

let render_preview_lines ~terminal_width ~selected =
  let content = content_for_selection ~max_bytes:max_preview_bytes selected in
  match selected with
  | None -> [ Text_width.clip ~width:terminal_width "preview: no selected result" ]
  | Some _ ->
      let title = Text_width.clip ~width:terminal_width (format_title ~scroll:0 ~visible_rows:1 content) in
      let first_line =
        match content.lines with
        | [] -> ""
        | line :: _ -> Text_width.clip ~width:terminal_width line
      in
      [ title; first_line ]
