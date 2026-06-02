(** Scoring and stable ranking for fuzzy matches. *)

(** A match with its original input position. *)
type candidate_match = {
  candidate : string;
  positions : int list;
  original_index : int;
}

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

(** [rank ~query matches] scores and ranks matches by descending score. Ties
    preserve [original_index] order. *)
val rank : query:string -> candidate_match list -> scored_match list
