(** Scoring and stable ranking for fuzzy matches. *)

(** A match with its original input position. *)
type candidate_match = {
  candidate : string;
  positions : int list;
  original_index : int;
}

val make_candidate_match :
  candidate:string -> positions:int list -> original_index:int -> candidate_match
  (** Construct a candidate match without exposing record-label disambiguation at
      call sites. *)

(** A scored match. Higher [score] values rank first. *)
type scored_match = {
  candidate : string;
  positions : int list;
  score : int;
  original_index : int;
}

(** Detailed score components used by documentation and tests. *)
type breakdown = {
  base : int;
  consecutive_bonus : int;
  boundary_bonus : int;
  early_bonus : int;
  exact_bonus : int;
  prefix_bonus : int;
  gap_penalty : int;
  path_penalty : int;
  length_penalty : int;
  total : int;
}

(** [score_breakdown ~query ~candidate ~positions] computes the full scoring
    model for a successful fuzzy match. [positions] must be zero-based byte
    positions in [candidate]. *)
val score_breakdown :
  query:string -> candidate:string -> positions:int list -> breakdown

(** [score ~query ~candidate ~positions] returns only the total score. *)
val score : query:string -> candidate:string -> positions:int list -> int

(** [score_match ~query match_] scores a successful candidate match. *)
val score_match : query:string -> candidate_match -> scored_match

(** [compare_scored a b] orders better scored matches first. Equal scores keep
    lower [original_index] first. *)
val compare_scored : scored_match -> scored_match -> int

(** [rank ~query matches] scores and ranks all matches by descending score. Ties
    preserve [original_index] order. *)
val rank : query:string -> candidate_match list -> scored_match list

(** [rank_top ~query ~k matches] scores all matches but keeps only the best [k]
    results without fully sorting every candidate. The returned list is sorted
    best first. *)
val rank_top : query:string -> k:int -> candidate_match list -> scored_match list
