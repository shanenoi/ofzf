type candidate_match = {
  candidate : string;
  positions : int list;
  original_index : int;
}

type scored_match = {
  candidate : string;
  positions : int list;
  score : int;
  original_index : int;
}

type breakdown = {
  base : int;
  consecutive_bonus : int;
  boundary_bonus : int;
  early_bonus : int;
  length_penalty : int;
  total : int;
}

let is_ascii_lower = function 'a' .. 'z' -> true | _ -> false
let is_ascii_upper = function 'A' .. 'Z' -> true | _ -> false

let is_separator = function
  | '/' | '-' | '_' | ' ' | '.' | ':' | '\t' -> true
  | _ -> false

let has_utf8_bullet_before candidate index =
  index >= 3
  && Char.code candidate.[index - 3] = 0xE2
  && Char.code candidate.[index - 2] = 0x97
  && Char.code candidate.[index - 1] = 0x8F

let is_camel_transition candidate index =
  index > 0
  && is_ascii_lower candidate.[index - 1]
  && is_ascii_upper candidate.[index]

let boundary_bonus_at candidate index =
  if index = 0 then 36
  else if is_separator candidate.[index - 1] then 28
  else if has_utf8_bullet_before candidate index then 28
  else if is_camel_transition candidate index then 24
  else 0

let consecutive_bonus positions =
  let rec loop previous total = function
    | [] -> total
    | position :: rest ->
        let bonus =
          match previous with
          | Some previous when position = previous + 1 -> 32
          | _ -> 0
        in
        loop (Some position) (total + bonus) rest
  in
  loop None 0 positions

let boundary_bonus candidate positions =
  List.fold_left (fun total position -> total + boundary_bonus_at candidate position) 0
    positions

let early_bonus positions =
  match positions with
  | [] -> 0
  | first :: _ -> max 0 (64 - (first * 4))

let score_breakdown ~query ~candidate ~positions =
  let base = String.length query * 100 in
  let consecutive_bonus = consecutive_bonus positions in
  let boundary_bonus = boundary_bonus candidate positions in
  let early_bonus = early_bonus positions in
  let length_penalty = String.length candidate in
  let total =
    base + consecutive_bonus + boundary_bonus + early_bonus - length_penalty
  in
  { base; consecutive_bonus; boundary_bonus; early_bonus; length_penalty; total }

let score ~query ~candidate ~positions =
  (score_breakdown ~query ~candidate ~positions).total

let score_match ~query (matched : candidate_match) =
  let score = score ~query ~candidate:matched.candidate ~positions:matched.positions in
  {
    candidate = matched.candidate;
    positions = matched.positions;
    score;
    original_index = matched.original_index;
  }

let compare_scored left right =
  match compare right.score left.score with
  | 0 -> compare left.original_index right.original_index
  | by_score -> by_score

let rank ~query matches =
  matches |> List.map (score_match ~query) |> List.sort compare_scored
