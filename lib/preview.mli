(** Preview-window layout and rendering helpers. *)

type position = Right | Bottom
(** Supported preview placements. *)

type rect = { row : int; col : int; rows : int; cols : int }
(** One-based terminal rectangle. *)

type layout = {
  enabled : bool;
  position : position option;
  results : rect;
  preview : rect option;
}
(** Computed interactive layout. [enabled = false] means the preview is hidden. *)

val min_result_rows : int
val min_preview_rows : int
val min_result_cols : int
val min_preview_cols : int

val parse_position : string -> position option
(** Parse [right] or [bottom]. *)

val position_to_string : position -> string

val compute_layout :
  terminal_rows:int -> terminal_cols:int -> preview:bool -> position:position -> layout
(** Compute result/preview areas after the two-line prompt/status header. *)

val render_preview_lines : terminal_width:int -> selected:string option -> string list
(** Render preview content without borders, clipped to terminal width. *)
