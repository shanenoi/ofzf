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
      | _ -> Plain_text_value candidate
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

let content_for_selection ~max_bytes = function
  | None ->
      {
        kind = No_selection;
        title = "no selected result";
        lines = [ "preview: no selected result" ];
        truncated = false;
      }
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
