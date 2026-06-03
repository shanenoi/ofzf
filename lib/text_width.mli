(** Display-width helpers for terminal rendering.

    The implementation intentionally avoids external Unicode dependencies while
    being safer than byte-length clipping. It decodes basic UTF-8, replaces
    invalid bytes with U+FFFD, treats common combining marks as zero-width, and
    treats common East Asian/emoji ranges as double-width. *)

type cell = {
  text : string;
  byte_start : int;
  byte_end : int;
  width : int;
}
(** One decoded display unit. [byte_start] and [byte_end] refer to byte indexes
    in the original input string. Invalid UTF-8 bytes are represented as the
    replacement character in [text] and consume one input byte. *)

type prompt_view = {
  visible : string;
  cursor_col : int;
}
(** Width-clipped prompt text plus a zero-based cursor display column. *)

val cells : ?tab_width:int -> string -> cell list
(** Decode text into display cells. *)

val sanitize : string -> string
(** Return text with invalid UTF-8 replaced by U+FFFD. *)

val display_width : ?tab_width:int -> string -> int
(** Best-effort terminal display width. ANSI escape sequences are not parsed;
    callers should not pass styled strings. *)

val display_width_until_byte : ?tab_width:int -> byte_index:int -> string -> int
(** Display width before [byte_index], counting only complete decoded cells. *)

val byte_index_for_display_column : ?tab_width:int -> column:int -> string -> int
(** Return a safe byte index at or before the requested display column. *)

val clip : ?tab_width:int -> width:int -> string -> string
(** Clip text to [width] display columns without cutting through UTF-8 bytes. *)

val slice : ?tab_width:int -> start_byte:int -> width:int -> string -> string
(** Return a width-clipped view beginning at the decoded cell containing or after
    [start_byte]. *)

val prompt_view :
  ?tab_width:int ->
  ?prompt:string ->
  terminal_width:int ->
  cursor_byte:int ->
  string ->
  prompt_view
(** Render a prompt so the query cursor remains visible where practical. *)
