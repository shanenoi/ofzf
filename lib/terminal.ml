type key =
  | Character of char
  | Backspace
  | Ctrl_b
  | Ctrl_e
  | Ctrl_f
  | Ctrl_u
  | Ctrl_w
  | Ctrl_y
  | Ctrl_c
  | Enter
  | Escape
  | Arrow_up
  | Arrow_down
  | Alt_up
  | Alt_down
  | Page_up
  | Page_down
  | Resize
  | Unknown of string

type size = { rows : int; cols : int }

external terminal_size_ioctl : Unix.file_descr -> (int * int) option = "ofzf_terminal_size_ioctl"

let fallback_size = { rows = 20; cols = 80 }

let normalize_size ?(fallback = fallback_size) size =
  {
    rows = (if size.rows > 0 then size.rows else fallback.rows);
    cols = (if size.cols > 0 then size.cols else fallback.cols);
  }

type handle = {
  fd : Unix.file_descr;
  previous : Unix.terminal_io;
  previous_sigwinch : Sys.signal_behavior;
  mutable restored : bool;
  mutable alternate_screen : bool;
}

let inverse = "\027[7m"
let reset = "\027[0m"
let highlight = "\027[1;4m"
let end_highlight = "\027[22;24m"
let selected_end_highlight = "\027[22;24;7m"

let resize_pending = ref false

let parse_key_sequence = function
  | "\002" -> Ctrl_b
  | "\003" -> Ctrl_c
  | "\005" -> Ctrl_e
  | "\006" -> Ctrl_f
  | "\021" -> Ctrl_u
  | "\023" -> Ctrl_w
  | "\025" -> Ctrl_y
  | "\r" | "\n" -> Enter
  | "\b" | "\127" -> Backspace
  | "\027" -> Escape
  | "\027[A" -> Arrow_up
  | "\027[B" -> Arrow_down
  | "\027\027[A" | "\027[1;3A" -> Alt_up
  | "\027\027[B" | "\027[1;3B" -> Alt_down
  | "\027[5~" -> Page_up
  | "\027[6~" -> Page_down
  | sequence when String.length sequence = 1 -> Character sequence.[0]
  | sequence -> Unknown sequence

let terminal_error prefix error function_name argument =
  let detail = if argument = "" then function_name else function_name ^ " " ^ argument in
  Error (Printf.sprintf "%s: %s (%s)" prefix (Unix.error_message error) detail)

let enter_raw_mode () =
  try
    let fd = Unix.openfile "/dev/tty" [ Unix.O_RDWR ] 0 in
    if not (Unix.isatty fd) then (
      Unix.close fd;
      Error "/dev/tty is not a terminal")
    else
      let previous = Unix.tcgetattr fd in
      resize_pending := false;
      let previous_sigwinch =
        Sys.signal Sys.sigwinch
          (Sys.Signal_handle (fun _signal -> resize_pending := true))
      in
      let raw =
        {
          previous with
          Unix.c_echo = false;
          c_icanon = false;
          c_isig = false;
          c_vmin = 1;
          c_vtime = 0;
        }
      in
      (try Unix.tcsetattr fd Unix.TCSANOW raw with exn ->
         Sys.set_signal Sys.sigwinch previous_sigwinch;
         Unix.close fd;
         raise exn);
      Ok { fd; previous; previous_sigwinch; restored = false; alternate_screen = false }
  with Unix.Unix_error (error, function_name, argument) ->
    terminal_error "cannot enter raw mode" error function_name argument

let write handle text =
  let rec loop offset =
    if offset < String.length text then
      let written = Unix.write_substring handle.fd text offset (String.length text - offset) in
      if written = 0 then () else loop (offset + written)
  in
  loop 0

let clear_screen handle = write handle "\027[2J"

let move_cursor handle ~row ~col =
  write handle (Printf.sprintf "\027[%d;%dH" (max 1 row) (max 1 col))

let hide_cursor handle = write handle "\027[?25l"
let show_cursor handle = write handle "\027[?25h"

let enter_alternate_screen handle =
  if not handle.alternate_screen then (
    handle.alternate_screen <- true;
    write handle "\027[?1049h")

let leave_alternate_screen handle =
  if handle.alternate_screen then (
    handle.alternate_screen <- false;
    write handle "\027[?1049l")

let restore handle =
  if not handle.restored then (
    handle.restored <- true;
    (try show_cursor handle with _ -> ());
    (try leave_alternate_screen handle with _ -> ());
    (try Sys.set_signal Sys.sigwinch handle.previous_sigwinch with _ -> ());
    (try Unix.tcsetattr handle.fd Unix.TCSANOW handle.previous with _ -> ());
    try Unix.close handle.fd with _ -> ())

exception Read_interrupted

let read_char fd =
  try
    let buffer = Bytes.create 1 in
    match Unix.read fd buffer 0 1 with
    | 0 -> None
    | _ -> Some (Bytes.get buffer 0)
  with Unix.Unix_error (Unix.EINTR, _, _) -> raise Read_interrupted

let read_char_with_timeout fd timeout =
  try
    match Unix.select [ fd ] [] [] timeout with
    | ready, _, _ when ready <> [] -> read_char fd
    | _ -> None
  with Unix.Unix_error (Unix.EINTR, _, _) -> raise Read_interrupted

let is_csi_final_byte char = Char.code char >= 0x40 && Char.code char <= 0x7e

let read_escape_sequence fd =
  match read_char_with_timeout fd 0.03 with
  | None -> "\027"
  | Some first ->
      let buffer = Buffer.create 8 in
      Buffer.add_char buffer '\027';
      Buffer.add_char buffer first;
      (if first = '[' then
        let rec loop remaining =
          if remaining > 0 then
            match read_char_with_timeout fd 0.03 with
            | Some char ->
                Buffer.add_char buffer char;
                if not (is_csi_final_byte char) then loop (remaining - 1)
            | None -> ()
        in
         loop 16);
      Buffer.contents buffer

let read_key handle =
  if !resize_pending then (
    resize_pending := false;
    Resize)
  else
    try
      match read_char handle.fd with
      | None -> Escape
      | Some '\027' -> parse_key_sequence (read_escape_sequence handle.fd)
      | Some char -> parse_key_sequence (String.make 1 char)
    with Read_interrupted ->
      if !resize_pending then (
        resize_pending := false;
        Resize)
      else Unknown ""

let int_env name =
  match Sys.getenv_opt name with
  | Some value -> int_of_string_opt value
  | None -> None

let size_from_ioctl_fd fd =
  match terminal_size_ioctl fd with
  | Some (rows, cols) -> Some (normalize_size { rows; cols })
  | None -> None

let size_from_tty_ioctl () =
  try
    let fd = Unix.openfile "/dev/tty" [ Unix.O_RDONLY ] 0 in
    Fun.protect
      ~finally:(fun () -> try Unix.close fd with _ -> ())
      (fun () -> if Unix.isatty fd then size_from_ioctl_fd fd else None)
  with Unix.Unix_error _ -> None

let size_from_env () =
  match (int_env "LINES", int_env "COLUMNS") with
  | Some rows, Some cols -> Some (normalize_size { rows; cols })
  | Some rows, None -> Some (normalize_size { fallback_size with rows })
  | None, Some cols -> Some (normalize_size { fallback_size with cols })
  | None, None -> None

let parse_stty_size line =
  match String.split_on_char ' ' line |> List.filter (fun value -> value <> "") with
  | rows :: cols :: _ -> (
      match (int_of_string_opt rows, int_of_string_opt cols) with
      | Some rows, Some cols -> Some (normalize_size { rows; cols })
      | _ -> None)
  | _ -> None

let size_from_stty () =
  try
    let channel = Unix.open_process_in "stty size < /dev/tty 2>/dev/null" in
    let line = input_line channel in
    ignore (Unix.close_process_in channel);
    parse_stty_size line
  with _ -> None

let terminal_size ?handle () =
  match Option.bind handle (fun handle -> size_from_ioctl_fd handle.fd) with
  | Some size -> size
  | None -> (
      match size_from_tty_ioctl () with
      | Some size -> size
      | None -> (
          match size_from_env () with
          | Some size -> size
          | None -> ( match size_from_stty () with Some size -> size | None -> fallback_size )))

let terminal_height () = (terminal_size ()).rows
let terminal_width () = (terminal_size ()).cols
