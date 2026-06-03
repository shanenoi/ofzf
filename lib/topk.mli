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

val of_list : k:int -> 'a item list -> 'a item list
(** [of_list ~k items] returns at most [k] best items, already sorted best
    first. [k <= 0] returns [[]]. Ties preserve original input order through
    [original_index]. *)
