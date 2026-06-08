(** Pure result selection helpers. *)

type action = Move_up | Move_down | Page_up | Page_down | Stay

val clamp : selected:int -> result_count:int -> int
val apply_action : ?page_size:int -> action -> selected:int -> result_count:int -> int

val selected_result :
  selected:int -> Matcher.match_result list -> Matcher.match_result option * int
(** Returns [(Some result, 0)] when a result exists, [(None, 1)] otherwise. *)

val selected_candidate_text : selected:int -> Matcher.match_result list -> string option

val preserve_selected_candidate :
  previous_candidate:string option -> fallback_selected:int -> Matcher.match_result list -> int
(** Keep the previously selected candidate when it still exists; otherwise clamp
    [fallback_selected] into the new result range. *)

val candidate_marked : marked:string list -> candidate:string -> bool
(** Whether [candidate] is present in the multi-select marked set. *)

val marked_candidates_in_input_order : candidates:string list -> marked:string list -> string list
(** Return marked candidates in original input order, dropping marks whose
    candidate no longer exists in the full candidate list. Duplicate candidate
    text is emitted once because the rest of the current selection model is
    candidate-text based. *)

val toggle_candidate : candidates:string list -> candidate:string -> marked:string list -> string list
(** Toggle [candidate] in the marked set and return marks in original input
    order. *)

val selected_candidate_outputs :
  candidates:string list -> marked:string list -> selected:int -> Matcher.match_result list -> string list * int
(** Multi-select Enter behavior. Marked candidates are returned in input order.
    When no candidates are marked, fall back to the currently highlighted
    result, matching single-select behavior. *)
