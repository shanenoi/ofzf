(** Interactive terminal UI MVP. *)

val result_rows : terminal_height:int -> int
(** Number of result rows available after prompt/status lines. *)

val clamp_selection : selected:int -> result_count:int -> int
(** Clamp the selected row into the available result range. *)

val visible_window : selected:int -> terminal_height:int -> result_count:int -> int * int
(** Return [(start, stop)] bounds for visible result rows. [stop] is exclusive. *)

val clip_plain : terminal_width:int -> string -> string
(** Clip a plain, non-ANSI string to the visible terminal display width. *)

val render_prompt :
  cursor_byte:int -> terminal_width:int -> query:string -> Text_width.prompt_view
(** Render the prompt and query using display-width-aware clipping. *)

val delete_previous_word : string -> string
(** Query-editing helper for Ctrl-W. *)

val apply_key_to_query : Terminal.key -> query:string -> string
(** Pure query editing helper. Non-editing keys leave the query unchanged. *)

val apply_key_to_selection : Terminal.key -> selected:int -> result_count:int -> int
(** Pure selection movement helper. *)

val format_status : result_count:int -> selected:int -> string
(** Human-readable status line for the current result set. *)

val empty_results_message : query:string -> string
(** Message shown when the current query has no matches. *)

val render_candidate : selected:bool -> positions:int list -> candidate:string -> string
(** Render one candidate with ANSI highlighting on matched byte positions. *)

val render_candidate_clipped :
  terminal_width:int -> selected:bool -> positions:int list -> candidate:string -> string
(** Render one candidate clipped to terminal width while preserving matched-byte
    highlighting inside the visible range. *)

val render_result_line : ?terminal_width:int -> selected:bool -> Matcher.match_result -> string
(** Render one result row, including selected-row styling when requested. *)

val render_lines :
  ?terminal_width:int ->
  terminal_height:int ->
  query:string ->
  selected:int ->
  Matcher.match_result list ->
  string list
(** Pure renderer used by tests. The returned list never contains more lines
    than [terminal_height]. *)

val selected_result : selected:int -> Matcher.match_result list -> (Matcher.match_result option * int)
(** Enter-key result helper. Returns [(Some result, 0)] when a result exists and
    [(None, 1)] when Enter is pressed with no selectable result. *)

val run : candidates:string list -> int
(** Run interactive mode. Returns the intended process exit code. *)
