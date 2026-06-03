let input_lines () =
  let rec loop acc =
    match input_line stdin with
    | line -> loop (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  loop []

let now = Sys.time

let count_matches ~query candidates =
  List.fold_left
    (fun count candidate ->
      if Ofzf.Matcher.matches ~query candidate then count + 1 else count)
    0 candidates

let () =
  let query =
    match Array.to_list Sys.argv with
    | _ :: query :: _ -> query
    | _ -> ""
  in
  let candidates = input_lines () in
  let candidate_count = List.length candidates in
  let match_start = now () in
  let matching_count = count_matches ~query candidates in
  let match_end = now () in
  let rank_start = now () in
  let ranked = Ofzf.Matcher.rank ~query candidates in
  let rank_end = now () in
  Printf.printf "candidate_count=%d\n" candidate_count;
  Printf.printf "query_length=%d\n" (String.length query);
  Printf.printf "matching_count=%d\n" matching_count;
  Printf.printf "matching_time_seconds=%.6f\n" (match_end -. match_start);
  Printf.printf "ranking_time_seconds=%.6f\n" (rank_end -. rank_start);
  Printf.printf "ranked_count=%d\n" (List.length ranked)
