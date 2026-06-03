(** Minimal terminal support for the interactive MVP.

    This module intentionally avoids ncurses and other UI dependencies. Runtime
    functions operate on [/dev/tty] so standard input can remain the candidate
    stream and standard output can remain the selected result stream. *)

type key =
  | Character of char
  | Backspace
  | Ctrl_c
  | Enter
  | Escape
  | Arrow_up
  | Arrow_down
  | Unknown of string
(** Decoded key events used by the interactive loop. *)

type handle
(** Raw-mode terminal handle. *)

val parse_key_sequence : string -> key
(** Pure key parser used by tests and by [read_key]. *)

val enter_raw_mode : unit -> (handle, string) result
(** Open [/dev/tty], save the current terminal mode, and enter raw mode. *)

val restore : handle -> unit
(** Restore the saved terminal mode and close the handle. Calling this more than
    once is safe. *)

val write : handle -> string -> unit
(** Write bytes to the terminal handle. *)

val clear_screen : handle -> unit
val move_cursor : handle -> row:int -> col:int -> unit
val hide_cursor : handle -> unit
val show_cursor : handle -> unit

val read_key : handle -> key
(** Read one key event from the terminal. *)

val terminal_height : unit -> int
(** Best-effort terminal height. Falls back to [20]. *)