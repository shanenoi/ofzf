(** Non-interactive search engine with query-cache support for future
    incremental UI use. *)

type stats = {
  candidate_count_scanned : int;
  candidates_matched : int;
  cache_hits : int;
  cache_misses : int;
  incremental_reuse_count : int;
  matching_time : float;
  ranking_time : float;
}
(** Statistics for the latest search operation. *)

type search_context
(** Incremental search state. It stores the previous query, previous candidate
    subset, result cache, and accumulated counters. *)

type search_result = {
  query : string;
  results : Matcher.match_result list;
  context : search_context;
  stats : stats;
}

val empty_context : search_context

val previous_query : search_context -> string option
val previous_candidate_subset : search_context -> string list
val context_stats : search_context -> stats

val full_search : ?limit:int -> query:string -> string list -> search_result
(** Search all candidates and return ranked matches. *)

val incremental_search :
  ?limit:int -> context:search_context -> query:string -> string list -> search_result
(** Search using cached or previous-prefix candidate subsets when safe; otherwise
    fallback to a full search. *)
