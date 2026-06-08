(** Minimal terminal support for the interactive MVP.

    This module intentionally avoids ncurses and other UI dependencies. Runtime
    functions operate on [/dev/tty] so standard input can remain the candidate
    stream and standard output can remain the selected result stream. *)

type key =
  | Character of char
  | Backspace
  | Delete
  | Ctrl_a
  | Ctrl_b
  | Ctrl_e
  | Ctrl_f
  | Ctrl_u
  | Ctrl_w
  | Ctrl_y
  | Ctrl_c
  | Enter
  | Escape
  | Arrow_left
  | Arrow_right
  | Arrow_up
  | Arrow_down
  | Home
  | End
  | Alt_up
  | Alt_down
  | Page_up
  | Page_down
  | Resize
  | Unknown of string
(** Decoded key events used by the interactive loop. *)

type handle
(** Raw-mode terminal handle. *)

type size = { rows : int; cols : int }
(** Terminal dimensions in rows and columns. *)

val fallback_size : size
(** Safe terminal dimensions used when detection fails. *)

val normalize_size : ?fallback:size -> size -> size
(** Pure helper that replaces non-positive dimensions with fallback values. *)

val parse_stty_size : string -> size option
(** Pure parser for [stty size] output, which is normally ["ROWS COLS"]. *)

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
val enter_alternate_screen : handle -> unit
val leave_alternate_screen : handle -> unit

val inverse : string
val reset : string
val highlight : string
val end_highlight : string
val selected_end_highlight : string
(** ANSI style fragments used by the interactive renderer. Keeping these in the
    terminal layer keeps styling escape sequences out of CLI/search code. *)

val read_key : handle -> key
(** Read one key event from the terminal. *)

val terminal_height : unit -> int
(** Best-effort terminal height. Falls back to [20]. *)

val terminal_width : unit -> int
(** Best-effort terminal width. Falls back to [80]. *)

val terminal_size : ?handle:handle -> unit -> size
(** Best-effort terminal size. Prefer ioctl on the active [/dev/tty] handle when
    available, then try ioctl on [/dev/tty], [LINES]/[COLUMNS], [stty size], and
    finally a safe fallback. *)
