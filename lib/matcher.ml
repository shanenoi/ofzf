type match_result = {
  candidate : string;
  original_index : int;
  positions : int list;
  score : int;
}

type prepared_query = {
  lower : string;
  length : int;
  scoring_query : Scoring.prepared_query;
}

let prepare_query value = {
  lower = String.lowercase_ascii value;
  length = String.length value;
  scoring_query = Scoring.prepare_query value;
}

let lowercase_ascii_char = function
  | 'A' .. 'Z' as char -> Char.chr (Char.code char + 32)
  | char -> char

let array_prefix_to_list values length =
  let rec loop index acc =
    if index < 0 then acc else loop (index - 1) (values.(index) :: acc)
  in
  loop (length - 1) []

let find_positions_prepared ~query ~candidate =
  let query_length = query.length in
  let candidate_length = String.length candidate in
  if query_length = 0 then Some []
  else if query_length > candidate_length then None
  else
    let positions = Array.make query_length 0 in
    let rec scan query_index candidate_index =
      if query_index = query_length then
        Some (array_prefix_to_list positions query_length)
      else if candidate_index = candidate_length then None
      else if
        query.lower.[query_index]
        = lowercase_ascii_char candidate.[candidate_index]
      then (
        positions.(query_index) <- candidate_index;
        scan (query_index + 1) (candidate_index + 1))
      else scan query_index (candidate_index + 1)
    in
    scan 0 0

let find_positions ~query ~candidate =
  find_positions_prepared ~query:(prepare_query query) ~candidate

let result_of_scored (scored : Scoring.scored_match) =
  {
    candidate = scored.Scoring.candidate;
    original_index = scored.Scoring.original_index;
    positions = scored.Scoring.positions;
    score = scored.Scoring.score;
  }

let match_prepared_indexed ~original_index ~query ~candidate =
  match find_positions_prepared ~query ~candidate with
  | None -> None
  | Some positions ->
      Some
        {
          candidate;
          original_index;
          positions;
          score =
            Scoring.score_prepared ~query:query.scoring_query ~candidate ~positions;
        }

let match_prepared ~query ~candidate =
  match_prepared_indexed ~original_index:0 ~query ~candidate

let match_candidate ~query ~candidate =
  match_prepared ~query:(prepare_query query) ~candidate

let matches ~query candidate =
  match find_positions ~query ~candidate with Some _ -> true | None -> false

let matches_prepared ~query candidate =
  match find_positions_prepared ~query ~candidate with Some _ -> true | None -> false

let rank ~query candidates =
  let query = prepare_query query in
  candidates
  |> List.mapi (fun original_index candidate ->
         match find_positions_prepared ~query ~candidate with
         | None -> None
         | Some positions ->
             let computed_score =
               Scoring.score_prepared ~query:query.scoring_query ~candidate ~positions
             in
             Some
               Scoring.{
                 candidate;
                 positions;
                 score = computed_score;
                 original_index;
               })
  |> List.filter_map Fun.id
  |> List.sort Scoring.compare_scored
  |> List.map result_of_scored


let rank_top ~query ~k candidates =
  let query = prepare_query query in
  let best = Topk.create ~k () in
  candidates
  |> List.iteri (fun original_index candidate ->
         match find_positions_prepared ~query ~candidate with
         | None -> ()
         | Some positions ->
             let computed_score =
               Scoring.score_prepared ~query:query.scoring_query ~candidate ~positions
             in
             Topk.push best
               {
                 value = { candidate; original_index; positions; score = computed_score };
                 score = computed_score;
                 original_index;
               });
  best |> Topk.to_sorted_list |> List.map (fun item -> item.Topk.value)
