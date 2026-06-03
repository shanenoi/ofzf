let input_lines () =
  let rec loop acc =
    match input_line stdin with
    | line -> loop (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  loop []

let now = Sys.time

let time thunk =
  let start = now () in
  let value = thunk () in
  let stop = now () in
  (value, stop -. start)

let parse_args argv =
  match Array.to_list argv with
  | [ _; query ] -> (query, 10)
  | [ _; "--limit"; raw_limit; query ] -> (
      match int_of_string_opt raw_limit with
      | Some limit when limit >= 0 -> (query, limit)
      | _ -> failwith "usage: benchmark [--limit N] QUERY")
  | _ -> failwith "usage: benchmark [--limit N] QUERY"

let count_matches ~query candidates =
  List.fold_left
    (fun count candidate ->
      if Ofzf.Matcher.matches ~query candidate then count + 1 else count)
    0 candidates

let () =
  let query, limit = parse_args Sys.argv in
  let candidates = input_lines () in
  let candidate_count = List.length candidates in
  let matching_count, matching_time =
    time (fun () -> count_matches ~query candidates)
  in
  let full_ranked, full_ranking_time =
    time (fun () -> Ofzf.Matcher.rank ~query candidates)
  in
  let topk_ranked, topk_ranking_time =
    time (fun () -> Ofzf.Matcher.rank_top ~query ~k:limit candidates)
  in
  Printf.printf "candidate_count=%d\n" candidate_count;
  Printf.printf "query_length=%d\n" (String.length query);
  Printf.printf "limit=%d\n" limit;
  Printf.printf "matching_count=%d\n" matching_count;
  Printf.printf "matching_time_seconds=%.6f\n" matching_time;
  Printf.printf "full_ranking_time_seconds=%.6f\n" full_ranking_time;
  Printf.printf "topk_ranking_time_seconds=%.6f\n" topk_ranking_time;
  Printf.printf "full_ranked_count=%d\n" (List.length full_ranked);
  Printf.printf "topk_ranked_count=%d\n" (List.length topk_ranked)
