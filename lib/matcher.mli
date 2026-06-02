(** Core fuzzy matcher functions for [ofzf]. *)

(** A successful match. *)
type match_result = {
  candidate : string;
  positions : int list;
  score : int;
}

(** [match_candidate ~query ~candidate] performs a case-insensitive fuzzy
    subsequence match.

    It returns [None] when every query character cannot be found in order. It
    returns [Some result] with zero-based byte match positions and a numeric
    score when the candidate matches. A higher score is better. *)
val match_candidate : query:string -> candidate:string -> match_result option

(** [matches ~query candidate] is [true] when [candidate] fuzzily matches
    [query]. *)
val matches : query:string -> string -> bool

(** [rank ~query candidates] filters and sorts candidates by descending score.
    Score ties preserve the original input order. *)
val rank : query:string -> string list -> match_result list
