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
