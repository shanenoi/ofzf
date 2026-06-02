type match_result = {
  candidate : string;
  positions : int list;
  score : int;
}

let is_boundary = function
  | '/' | '-' | '_' | ' ' | '.' | ':' -> true
  | _ -> false

let boundary_bonus candidate index =
  if index = 0 then 35
  else if is_boundary candidate.[index - 1] then 25
  else 0

let consecutive_bonus previous_position position =
  match previous_position with
  | Some previous when position = previous + 1 -> 20
  | _ -> 0

let compute_score ~query_length ~candidate ~positions =
  let base = query_length * 100 in
  let start_penalty =
    match positions with
    | first :: _ -> first * 3
    | [] -> 0
  in
  let length_penalty = String.length candidate in
  let rec loop previous total = function
    | [] -> total
    | position :: rest ->
        let total =
          total
          + boundary_bonus candidate position
          + consecutive_bonus previous position
        in
        loop (Some position) total rest
  in
  base + loop None 0 positions - start_penalty - length_penalty

let match_candidate ~query ~candidate =
  let query_length = String.length query in
  if query_length = 0 then
    Some { candidate; positions = []; score = -String.length candidate }
  else
    let query_lower = String.lowercase_ascii query in
    let candidate_lower = String.lowercase_ascii candidate in
    let candidate_length = String.length candidate in
    let rec scan query_index candidate_index positions =
      if query_index = query_length then
        let positions = List.rev positions in
        Some
          {
            candidate;
            positions;
            score = compute_score ~query_length ~candidate ~positions;
          }
      else if candidate_index = candidate_length then None
      else if query_lower.[query_index] = candidate_lower.[candidate_index] then
        scan (query_index + 1) (candidate_index + 1) (candidate_index :: positions)
      else scan query_index (candidate_index + 1) positions
    in
    scan 0 0 []

let matches ~query candidate =
  match match_candidate ~query ~candidate with
  | Some _ -> true
  | None -> false

let compare_result left right =
  match compare right.score left.score with
  | 0 -> compare left.candidate right.candidate
  | by_score -> by_score

let rank ~query candidates =
  candidates
  |> List.filter_map (fun candidate -> match_candidate ~query ~candidate)
  |> List.sort compare_result
