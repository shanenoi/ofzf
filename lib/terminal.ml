type key =
  | Character of char
  | Backspace
  | Ctrl_c
  | Enter
  | Escape
  | Arrow_up
  | Arrow_down
  | Unknown of string

type handle = {
  fd : Unix.file_descr;
  previous : Unix.terminal_io;
  mutable restored : bool;
  mutable alternate_screen : bool;
}

let inverse = "\027[7m"
let reset = "\027[0m"
let highlight = "\027[1;4m"
let end_highlight = "\027[22;24m"
let selected_end_highlight = "\027[22;24;7m"

let parse_key_sequence = function
  | "\003" -> Ctrl_c
  | "\r" | "\n" -> Enter
  | "\b" | "\127" -> Backspace
  | "\027" -> Escape
  | "\027[A" -> Arrow_up
  | "\027[B" -> Arrow_down
  | sequence when String.length sequence = 1 -> Character sequence.[0]
  | sequence -> Unknown sequence

let terminal_error prefix error function_name argument =
    let detail =
      if argument = "" then function_name else function_name ^ " " ^ argument
    in
    Error
      (Printf.sprintf "%s: %s (%s)" prefix (Unix.error_message error) detail)

let enter_raw_mode () =
  try
      let fd = Unix.openfile "/dev/tty" [ Unix.O_RDWR ] 0 in
      if not (Unix.isatty fd) then (
        Unix.close fd;
        Error "/dev/tty is not a terminal")
      else
      let previous = Unix.tcgetattr fd in
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
      Unix.tcsetattr fd Unix.TCSANOW raw;
      Ok { fd; previous; restored = false; alternate_screen = false }
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
    (try Unix.tcsetattr handle.fd Unix.TCSANOW handle.previous with _ -> ());
    try Unix.close handle.fd with _ -> ())

let read_char fd =
  let buffer = Bytes.create 1 in
  match Unix.read fd buffer 0 1 with
  | 0 -> None
  | _ -> Some (Bytes.get buffer 0)

let read_char_with_timeout fd timeout =
  match Unix.select [ fd ] [] [] timeout with
  | ready, _, _ when ready <> [] -> read_char fd
  | _ -> None

let read_key handle =
  match read_char handle.fd with
  | None -> Escape
  | Some '\027' -> (
      match read_char_with_timeout handle.fd 0.03 with
      | None -> Escape
      | Some '[' -> (
          match read_char_with_timeout handle.fd 0.03 with
          | Some suffix -> parse_key_sequence (String.of_seq (List.to_seq [ '\027'; '['; suffix ]))
          | None -> Unknown "\027[")
      | Some other -> Unknown (String.of_seq (List.to_seq [ '\027'; other ])))
  | Some char -> parse_key_sequence (String.make 1 char)

let int_env name =
  match Sys.getenv_opt name with
  | Some value -> int_of_string_opt value
  | None -> None

let height_from_stty () =
  try
    let channel = Unix.open_process_in "stty size < /dev/tty 2>/dev/null" in
    let line = input_line channel in
    ignore (Unix.close_process_in channel);
    match String.split_on_char ' ' line with
    | rows :: _ -> int_of_string_opt rows
    | _ -> None
  with _ -> None

let terminal_height () =
  match int_env "LINES" with
  | Some rows when rows > 0 -> rows
  | _ -> (
      match height_from_stty () with
      | Some rows when rows > 0 -> rows
      | _ -> 20)