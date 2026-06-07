(** Bounded stable top-k ranking helpers. *)

type 'a item = {
  value : 'a;
  score : int;
  original_index : int;
}
(** Ranked item. Higher [score] is better. [original_index] breaks score ties
    in favor of earlier input. *)

val compare : 'a item -> 'a item -> int
(** [compare a b] orders best items first: descending score, then ascending
    original index. *)

type 'a t
(** Bounded heap accumulator. The weakest retained item is kept at the heap root
    internally; callers only observe sorted best-first results through
    [to_sorted_list]. *)

val create : k:int -> unit -> 'a t
(** [create ~k ()] creates an empty top-k accumulator. [k <= 0] creates a
    disabled accumulator that retains no items. *)

val push : 'a t -> 'a item -> unit
(** [push heap item] adds [item] when the heap has room, or replaces the weakest
    retained item when [item] is better. Items worse than or equal to the current
    weakest retained item are skipped. *)

val length : 'a t -> int
(** [length heap] returns the number of retained items. *)

val to_sorted_list : 'a t -> 'a item list
(** [to_sorted_list heap] returns retained items sorted best first. *)

val of_list : k:int -> 'a item list -> 'a item list
(** [of_list ~k items] returns at most [k] best items, already sorted best
    first. [k <= 0] returns [[]]. Ties preserve original input order through
    [original_index]. *)

val add : k:int -> 'a item list -> 'a item -> 'a item list
(** Compatibility helper. [add ~k best item] returns the best [k] items from
    [item :: best], sorted best first. Streaming callers should prefer [create],
    [push], and [to_sorted_list] so they keep heap state across candidates. *)
