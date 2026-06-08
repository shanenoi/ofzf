(** Interactive terminal UI MVP. *)

type preview_state = {
  selected_candidate : string option;
  content : Preview.content;
  scroll : int;
}
(** Loaded preview state. Rendering consumes this state instead of reading files. *)

val result_rows : terminal_height:int -> int
(** Number of result rows available after prompt/status lines. *)

val clamp_selection : selected:int -> result_count:int -> int
(** Clamp the selected row into the available result range. *)

val visible_window_for_rows : selected:int -> visible_rows:int -> result_count:int -> int * int
(** Return [(start, stop)] bounds for an already-computed result-pane height. *)

val visible_window : selected:int -> terminal_height:int -> result_count:int -> int * int
(** Return [(start, stop)] bounds for visible result rows without preview. *)

val clip_plain : terminal_width:int -> string -> string
(** Clip a plain, non-ANSI string to the visible terminal display width. *)

val render_prompt :
  cursor_byte:int -> terminal_width:int -> query:string -> Text_width.prompt_view
(** Render the prompt and query using display-width-aware clipping. *)

val delete_previous_word : string -> string
(** Query-editing helper for Ctrl-W. *)

val apply_key_to_query : Terminal.key -> query:string -> string
(** Pure query editing helper. Non-editing keys leave the query unchanged. *)

val apply_key_to_query_edit : Terminal.key -> Query_edit.t -> Query_edit.t
(** Cursor-aware query editing helper. Non-editing keys leave query and cursor
    unchanged. *)

val apply_key_to_selection : ?page_size:int -> Terminal.key -> selected:int -> result_count:int -> int
(** Pure selection movement helper. *)

val preview_scroll_delta : visible_rows:int -> Terminal.key -> int option
(** Preview-scroll delta for keys that control the preview pane. *)

val format_status : multi_selected_count:int option -> preview:bool -> result_count:int -> selected:int -> string
(** Human-readable status line for the current result set. *)

val empty_results_message : query:string -> string
(** Message shown when the current query has no matches. *)

val render_candidate : selected:bool -> positions:int list -> candidate:string -> string
(** Render one candidate with ANSI highlighting on matched byte positions. *)

val render_candidate_clipped :
  terminal_width:int -> selected:bool -> positions:int list -> candidate:string -> string
(** Render one candidate clipped to terminal width while preserving matched-byte
    highlighting inside the visible range. *)

val render_result_line :
  ?terminal_width:int -> ?multi:bool -> ?marked:bool -> selected:bool -> Matcher.match_result -> string
(** Render one result row, including selected-row styling when requested. *)

val render_preview_pane :
  terminal_width:int -> height:int -> scroll:int -> Preview.content -> string list
(** Pure preview-pane renderer used by tests. *)

val render_lines :
  ?terminal_width:int ->
  ?cursor_byte:int ->
  ?preview:bool ->
  ?preview_position:Preview.position ->
  ?preview_content:Preview.content ->
  ?preview_scroll:int ->
  ?marked_candidates:string list ->
  ?multi_selected_count:int ->
  terminal_height:int ->
  query:string ->
  selected:int ->
  Matcher.match_result list ->
  string list
(** Pure renderer used by tests. The returned list never contains more lines
    than [terminal_height]. Preview content must be supplied by state-update code
    when preview is enabled. *)

val selected_result : selected:int -> Matcher.match_result list -> (Matcher.match_result option * int)
(** Enter-key result helper. Returns [(Some result, 0)] when a result exists and
    [(None, 1)] when Enter is pressed with no selectable result. *)

val toggle_candidate_selection : candidates:string list -> candidate:string -> marked:string list -> string list
(** Toggle one candidate in the multi-select marked set. *)

val selected_candidate_outputs :
  candidates:string list -> marked:string list -> selected:int -> Matcher.match_result list -> string list * int
(** Multi-select Enter-key result helper. *)

val preview_visible_rows :
  terminal_height:int -> terminal_width:int -> preview:bool -> preview_position:Preview.position -> int
(** Number of scrollable preview content rows for the current terminal layout. *)

val default_preview_state : preview_state
(** Empty preview state used before a result is selected. *)

val update_preview_state :
  ?loader:(string option -> Preview.content) -> preview_state -> string option -> preview_state
(** Reload preview content only when the selected candidate changes. *)

val clamp_preview_state_scroll : visible_rows:int -> preview_state -> preview_state
(** Clamp preview scroll based on already-loaded content. *)

val run :
  preview:bool -> multi:bool -> preview_position:Preview.position -> initial_query:string -> candidates:string list -> int
(** Run interactive mode. Returns the intended process exit code. *)
