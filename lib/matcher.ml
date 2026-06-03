type match_result = {
  candidate : string;
  positions : int list;
  score : int;
}

let find_positions ~query ~candidate =
  let query_length = String.length query in
  if query_length = 0 then Some []
  else
    let query_lower = String.lowercase_ascii query in
    let candidate_lower = String.lowercase_ascii candidate in
    let candidate_length = String.length candidate in
    let rec scan query_index candidate_index positions =
      if query_index = query_length then Some (List.rev positions)
      else if candidate_index = candidate_length then None
      else if query_lower.[query_index] = candidate_lower.[candidate_index] then
        scan (query_index + 1) (candidate_index + 1) (candidate_index :: positions)
      else scan query_index (candidate_index + 1) positions
    in
    scan 0 0 []

let result_of_scored (scored : Scoring.scored_match) =
  {
    candidate = scored.candidate;
    positions = scored.positions;
    score = scored.score;
  }

let match_candidate ~query ~candidate =
  match find_positions ~query ~candidate with
  | None -> None
  | Some positions ->
      Some
        {
          candidate;
          positions;
          score = Scoring.score ~query ~candidate ~positions;
        }

let matches ~query candidate =
  match find_positions ~query ~candidate with Some _ -> true | None -> false

let rank ~query candidates =
  candidates
  |> List.mapi (fun original_index candidate ->
         match find_positions ~query ~candidate with
         | None -> None
         | Some positions ->
             Some Scoring.{ candidate; positions; original_index })
  |> List.filter_map Fun.id
  |> Scoring.rank ~query
  |> List.map result_of_scored


let rank_top ~query ~k candidates =
  candidates
  |> List.mapi (fun original_index candidate ->
         match find_positions ~query ~candidate with
         | None -> None
         | Some positions ->
             Some Scoring.{ candidate; positions; original_index })
  |> List.filter_map Fun.id
  |> Scoring.rank_top ~query ~k
  |> List.map result_of_scored
