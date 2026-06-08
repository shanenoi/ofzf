(** Pure ANSI renderer for the interactive terminal UI. Rendering receives all
    loaded preview content from state-update code and performs no filesystem IO. *)

val clip_plain : terminal_width:int -> string -> string
val render_prompt : cursor_byte:int -> terminal_width:int -> query:string -> Text_width.prompt_view
val format_status : preview:bool -> result_count:int -> selected:int -> string
val empty_results_message : query:string -> string

val render_candidate : selected:bool -> positions:int list -> candidate:string -> string
val render_candidate_clipped :
  terminal_width:int -> selected:bool -> positions:int list -> candidate:string -> string
val render_result_line : ?terminal_width:int -> selected:bool -> Matcher.match_result -> string

val render_preview_pane :
  terminal_width:int -> height:int -> scroll:int -> Preview.content -> string list
val render_preview_box : width:int -> height:int -> scroll:int -> Preview.content -> string list

val render_lines :
  ?terminal_width:int ->
  ?cursor_byte:int ->
  ?preview:bool ->
  ?preview_position:Preview.position ->
  ?preview_content:Preview.content ->
  ?preview_scroll:int ->
  terminal_height:int ->
  query:string ->
  selected:int ->
  Matcher.match_result list ->
  string list
