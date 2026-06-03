(** Query-result cache for incremental search. *)

type 'a entry = {
  query : string;
  results : 'a list;
}

type 'a t

val default_max_entries : int
val create : ?max_entries:int -> unit -> 'a t
val empty : 'a t
val entries : 'a t -> 'a entry list
val max_entries : 'a t -> int

val add : query:string -> results:'a list -> 'a t -> 'a t
(** Add or replace a query. The cache evicts oldest entries deterministically
    once [max_entries] is exceeded. [max_entries <= 0] keeps no entries. *)

val find : query:string -> 'a t -> 'a list option
val is_prefix : prefix:string -> query:string -> bool
val longest_prefix : query:string -> 'a t -> 'a entry option
