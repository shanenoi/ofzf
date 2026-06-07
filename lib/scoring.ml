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

type prepared_query = {
  lower : string;
  length : int;
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

let make_candidate_match ~candidate ~positions ~original_index =
  ({ candidate; positions; original_index } : candidate_match)

let prepare_query value = {
  lower = String.lowercase_ascii value;
  length = String.length value;
}

let is_ascii_lower = function 'a' .. 'z' -> true | _ -> false
let is_ascii_upper = function 'A' .. 'Z' -> true | _ -> false

let lowercase_ascii_char = function
  | 'A' .. 'Z' as char -> Char.chr (Char.code char + 32)
  | char -> char

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

let equals_query_ignore_case ~query candidate =
  String.length candidate = query.length
  &&
  let rec loop index =
    if index = query.length then true
    else if lowercase_ascii_char candidate.[index] <> query.lower.[index] then false
    else loop (index + 1)
  in
  loop 0

let starts_with_query_ignore_case ~query candidate =
  String.length candidate >= query.length
  &&
  let rec loop index =
    if index = query.length then true
    else if lowercase_ascii_char candidate.[index] <> query.lower.[index] then false
    else loop (index + 1)
  in
  loop 0

let exact_bonus_prepared ~query ~candidate =
  if equals_query_ignore_case ~query candidate then 160 else 0

let prefix_bonus_prepared ~query ~candidate =
  if query.length = 0 then 0
  else if starts_with_query_ignore_case ~query candidate then 80
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

let consecutive_and_gap_penalty positions =
  let rec loop previous consecutive_total gap_total = function
    | [] -> (consecutive_total, gap_total)
    | position :: rest ->
        let consecutive, gap =
          match previous with
          | Some previous when position = previous + 1 -> (32, 0)
          | Some previous -> (0, max 0 (position - previous - 1) * 8)
          | None -> (0, 0)
        in
        loop (Some position) (consecutive_total + consecutive) (gap_total + gap) rest
  in
  loop None 0 0 positions

let score_total ~query ~candidate ~positions =
  let base = query.length * 100 in
  let consecutive_bonus, gap_penalty = consecutive_and_gap_penalty positions in
  let boundary_bonus = boundary_bonus candidate positions in
  let early_bonus = early_bonus positions in
  let exact_bonus = exact_bonus_prepared ~query ~candidate in
  let prefix_bonus = prefix_bonus_prepared ~query ~candidate in
  let path_penalty = path_penalty candidate positions in
  let length_penalty = String.length candidate in
  base + consecutive_bonus + boundary_bonus + early_bonus + exact_bonus
  + prefix_bonus - gap_penalty - path_penalty - length_penalty

let score_breakdown_prepared ~query ~candidate ~positions =
  let base = query.length * 100 in
  let consecutive_bonus = consecutive_bonus positions in
  let boundary_bonus = boundary_bonus candidate positions in
  let early_bonus = early_bonus positions in
  let exact_bonus = exact_bonus_prepared ~query ~candidate in
  let prefix_bonus = prefix_bonus_prepared ~query ~candidate in
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

let score_breakdown ~query ~candidate ~positions =
  score_breakdown_prepared ~query:(prepare_query query) ~candidate ~positions

let score ~query ~candidate ~positions =
  score_total ~query:(prepare_query query) ~candidate ~positions

let score_prepared ~query ~candidate ~positions = score_total ~query ~candidate ~positions

let score_match ~query (matched : candidate_match) =
  let query = prepare_query query in
  let candidate = matched.candidate in
  let positions = matched.positions in
  let original_index = matched.original_index in
  let score = score_prepared ~query ~candidate ~positions in
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
  let query = prepare_query query in
  matches
  |> List.map (fun (matched : candidate_match) ->
         let candidate = matched.candidate in
         let positions = matched.positions in
         let original_index = matched.original_index in
         let score = score_prepared ~query ~candidate ~positions in
         { candidate; positions; score; original_index })
  |> List.sort compare_scored

let rank_top ~query ~k matches =
  let query = prepare_query query in
  let best = Topk.create ~k () in
  matches
  |> List.iter (fun (matched : candidate_match) ->
         let candidate = matched.candidate in
         let positions = matched.positions in
         let original_index = matched.original_index in
         let score = score_prepared ~query ~candidate ~positions in
         let scored : scored_match = { candidate; positions; score; original_index } in
         let score = scored.score in
         let original_index = scored.original_index in
         Topk.push best { Topk.value = scored; score; original_index });
  best |> Topk.to_sorted_list |> List.map (fun item -> item.Topk.value)
