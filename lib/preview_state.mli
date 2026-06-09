(** Loaded preview state and scroll helpers. *)

type t = {
  selected_candidate : string option;
  source : Preview.source;
  content : Preview.content;
  scroll : int;
}

val default : t
val load_content : source:Preview.source -> string option -> Preview.content
val update :
  ?source:Preview.source ->
  ?loader:(source:Preview.source -> string option -> Preview.content) ->
  t ->
  string option ->
  t
val clamp_scroll : visible_rows:int -> t -> t
val scroll_delta : visible_rows:int -> Terminal.key -> int option
val apply_scroll_key : visible_rows:int -> Terminal.key -> t -> t option
