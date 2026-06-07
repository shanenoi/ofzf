(** Core fuzzy matcher functions for [ofzf]. *)

(** A successful match. *)
type match_result = {
  candidate : string;
  positions : int list;
  score : int;
}

(** A query normalized once for repeated matching. *)
type prepared_query

val prepare_query : string -> prepared_query
  (** [prepare_query query] prepares [query] for repeated fuzzy matching. It is
      useful on hot paths that compare the same query against many candidates. *)

(** [match_candidate ~query ~candidate] performs a case-insensitive fuzzy
    subsequence match.

    It returns [None] when every query character cannot be found in order. It
    returns [Some result] with zero-based byte match positions and a numeric
    score when the candidate matches. A higher score is better. *)
val match_candidate : query:string -> candidate:string -> match_result option

(** [match_prepared ~query ~candidate] is equivalent to [match_candidate] but
    reuses a prepared query. *)
val match_prepared : query:prepared_query -> candidate:string -> match_result option

(** [matches ~query candidate] is [true] when [candidate] fuzzily matches
    [query]. *)
val matches : query:string -> string -> bool

(** [matches_prepared ~query candidate] is equivalent to [matches] but reuses a
    prepared query. *)
val matches_prepared : query:prepared_query -> string -> bool

(** [rank ~query candidates] filters and sorts candidates by descending score.
    Score ties preserve the original input order. *)
val rank : query:string -> string list -> match_result list

(** [rank_top ~query ~k candidates] filters candidates and returns at most [k]
    best ranked matches without fully sorting every matching candidate. *)
val rank_top : query:string -> k:int -> string list -> match_result list
