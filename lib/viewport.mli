(** Pure result viewport helpers. *)

val header_rows : int
val result_rows : terminal_height:int -> int
val visible_window_for_rows : selected:int -> visible_rows:int -> result_count:int -> int * int
val visible_window : selected:int -> terminal_height:int -> result_count:int -> int * int

val layout_for_render :
  terminal_height:int ->
  terminal_width:int option ->
  preview:bool ->
  preview_position:Preview.position ->
  Preview.layout

val result_visible_rows :
  terminal_height:int ->
  terminal_width:int option ->
  preview:bool ->
  preview_position:Preview.position ->
  int
