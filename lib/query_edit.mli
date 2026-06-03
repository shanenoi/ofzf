(** Pure query editing helpers. This module has no terminal/runtime dependency. *)

type t = {
  query : string;
  cursor : int;
}
(** Query text plus byte cursor. Cursor values are clamped to UTF-8 byte
    boundaries where practical. *)

type action =
  | Insert of char
  | Backspace
  | Delete
  | Clear
  | Delete_previous_word
  | Move_left
  | Move_right
  | Move_start
  | Move_end
  | Ignore

val make : ?cursor:int -> string -> t
val query : t -> string
val cursor : t -> int
val clamp_cursor : string -> int -> int
val previous_boundary : string -> int -> int
val next_boundary : string -> int -> int

val apply : action -> t -> t
(** Apply a cursor-aware edit action. *)

val delete_previous_word : string -> string
(** Backward-compatible append-mode Ctrl-W helper. *)

val apply_append_action : action -> query:string -> string
(** Apply an action with the cursor at the end of the query. *)
