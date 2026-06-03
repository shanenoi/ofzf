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
  exact_bonus : int;
  prefix_bonus : int;
  gap_penalty : int;
  path_penalty : int;
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
  List.fold_left
    (fun total position -> total + boundary_bonus_at candidate position)
    0 positions

let early_bonus positions =
  match positions with
  | [] -> 0
  | first :: _ -> max 0 (64 - (first * 4))

let gap_penalty positions =
  let rec loop previous total = function
    | [] -> total
    | position :: rest ->
        let gap =
          match previous with
          | Some previous -> max 0 (position - previous - 1)
          | None -> 0
        in
        loop (Some position) (total + (gap * 8)) rest
  in
  loop None 0 positions

let lowercase_ascii value = String.lowercase_ascii value

let starts_with ~prefix value =
  let prefix_length = String.length prefix in
  String.length value >= prefix_length
  && String.sub value 0 prefix_length = prefix

let exact_bonus ~query ~candidate =
  if lowercase_ascii query = lowercase_ascii candidate then 160 else 0

let prefix_bonus ~query ~candidate =
  let query_lower = lowercase_ascii query in
  let candidate_lower = lowercase_ascii candidate in
  if query_lower = "" then 0
  else if starts_with ~prefix:query_lower candidate_lower then 80
  else 0

let path_penalty candidate positions =
  match positions with
  | [] -> 0
  | first :: _ ->
      let slash_count = ref 0 in
      for index = 0 to first - 1 do
        if candidate.[index] = '/' then incr slash_count
      done;
      !slash_count * 16

let score_breakdown ~query ~candidate ~positions =
  let base = String.length query * 100 in
  let consecutive_bonus = consecutive_bonus positions in
  let boundary_bonus = boundary_bonus candidate positions in
  let early_bonus = early_bonus positions in
  let exact_bonus = exact_bonus ~query ~candidate in
  let prefix_bonus = prefix_bonus ~query ~candidate in
  let gap_penalty = gap_penalty positions in
  let path_penalty = path_penalty candidate positions in
  let length_penalty = String.length candidate in
  let total =
    base + consecutive_bonus + boundary_bonus + early_bonus + exact_bonus
    + prefix_bonus - gap_penalty - path_penalty - length_penalty
  in
  {
    base;
    consecutive_bonus;
    boundary_bonus;
    early_bonus;
    exact_bonus;
    prefix_bonus;
    gap_penalty;
    path_penalty;
    length_penalty;
    total;
  }

let score ~query ~candidate ~positions =
  (score_breakdown ~query ~candidate ~positions).total

let score_match ~query ({ candidate; positions; original_index } : candidate_match) =
  let score = score ~query ~candidate ~positions in
  {
    candidate;
    positions;
    score;
    original_index;
  }

let compare_scored left right =
  match compare right.score left.score with
  | 0 -> compare left.original_index right.original_index
  | by_score -> by_score

let rank ~query matches =
  matches |> List.map (score_match ~query) |> List.sort compare_scored

let rank_top ~query ~k matches =
  matches
  |> List.map (fun matched ->
         let scored = score_match ~query matched in
         let score = scored.score in
         let original_index = scored.original_index in
         { Topk.value = scored; score; original_index })
  |> Topk.of_list ~k
  |> List.map (fun item -> item.Topk.value)
