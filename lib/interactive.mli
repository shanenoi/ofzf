(** Interactive terminal UI MVP. *)

val result_rows : terminal_height:int -> int
(** Number of result rows available after prompt/status lines. *)

val clamp_selection : selected:int -> result_count:int -> int
(** Clamp the selected row into the available result range. *)

val visible_window : selected:int -> terminal_height:int -> result_count:int -> int * int
(** Return [(start, stop)] bounds for visible result rows. [stop] is exclusive. *)

val apply_key_to_query : Terminal.key -> query:string -> string
(** Pure query editing helper. Non-editing keys leave the query unchanged. *)

val apply_key_to_selection : Terminal.key -> selected:int -> result_count:int -> int
(** Pure selection movement helper. *)

val run : candidates:string list -> int
(** Run interactive mode. Returns the intended process exit code. *)