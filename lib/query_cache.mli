(** Query result cache for incremental fuzzy search. *)

type 'a entry = {
  query : string;
  results : 'a list;
}
(** Cached result subset for one exact query. *)

type 'a t
(** Cache keyed by exact query text. *)

val empty : 'a t
(** Empty cache. *)

val add : query:string -> results:'a list -> 'a t -> 'a t
(** Store or replace the result subset for [query]. *)

val find : query:string -> 'a t -> 'a list option
(** Exact query lookup. *)

val is_prefix : prefix:string -> query:string -> bool
(** [is_prefix ~prefix ~query] is true when [query] extends [prefix]. *)

val longest_prefix : query:string -> 'a t -> 'a entry option
(** Return the cached entry with the longest query that is a prefix of [query].
    Exact matches are included. *)
