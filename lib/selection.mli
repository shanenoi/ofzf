(** Pure result selection helpers. *)

type action = Move_up | Move_down | Page_up | Page_down | Stay

val clamp : selected:int -> result_count:int -> int
val apply_action : ?page_size:int -> action -> selected:int -> result_count:int -> int

val selected_result :
  selected:int -> Matcher.match_result list -> Matcher.match_result option * int
(** Returns [(Some result, 0)] when a result exists, [(None, 1)] otherwise. *)

val selected_candidate_text : selected:int -> Matcher.match_result list -> string option

val selected_candidate_id : selected:int -> Matcher.match_result list -> int option
(** Return the original input index of the highlighted result. *)

val preserve_selected_candidate_id :
  previous_candidate_id:int option -> fallback_selected:int -> Matcher.match_result list -> int
(** Keep the previously highlighted input item when it still exists in the new
    result set; otherwise clamp [fallback_selected] into the new result range. *)

val candidate_marked : marked_candidate_ids:int list -> candidate_id:int -> bool
(** Whether [candidate_id] is present in the multi-select marked set. *)

val normalize_marked_candidate_ids : int list -> int list
(** Sort and deduplicate marked candidate IDs into original input order. *)

val toggle_candidate_id : candidate_id:int -> marked_candidate_ids:int list -> int list
(** Toggle [candidate_id] in the marked set. Returned IDs are sorted by original
    input order and deduplicated. *)

val marked_candidates_in_input_order :
  candidates:string list -> marked_candidate_ids:int list -> string list
(** Return marked candidates in original input order. Duplicate candidate text is
    preserved when the duplicate lines have distinct input indexes. *)

val selected_candidate_outputs :
  candidates:string list -> marked_candidate_ids:int list -> selected:int -> Matcher.match_result list -> string list * int
(** Multi-select Enter behavior. Marked candidates are returned in input order.
    When no candidates are marked, fall back to the currently highlighted
    result, matching single-select behavior. *)
