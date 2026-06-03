let input_lines () =
  let rec loop acc =
    match input_line stdin with
    | line -> loop (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  loop []

let parse_args argv =
  match Array.to_list argv with
  | [ _; query ] -> (query, Some 10)
  | [ _; "--limit"; raw_limit; query ] -> (
      match int_of_string_opt raw_limit with
      | Some limit when limit >= 0 -> (query, Some limit)
      | _ -> failwith "usage: benchmark [--limit N] QUERY")
  | _ -> failwith "usage: benchmark [--limit N] QUERY"

let prefixes query =
  let rec loop length acc =
    if length > String.length query then List.rev acc
    else loop (length + 1) (String.sub query 0 length :: acc)
  in
  if query = "" then [ "" ] else loop 1 []

let () =
  let query, limit = parse_args Sys.argv in
  let candidates = input_lines () in
  let candidate_count = List.length candidates in
  let full = Ofzf.Search_engine.full_search ?limit ~query candidates in
  let final_incremental =
    List.fold_left
      (fun context prefix ->
        let result = Ofzf.Search_engine.incremental_search ?limit ~context ~query:prefix candidates in
        result.context)
      Ofzf.Search_engine.empty_context (prefixes query)
  in
  let incremental = Ofzf.Search_engine.context_stats final_incremental in
  let reduction =
    if candidate_count = 0 then 0.0
    else 1.0 -. (float_of_int incremental.candidate_count_scanned /. float_of_int candidate_count)
  in
  Printf.printf "candidate_count=%d\n" candidate_count;
  Printf.printf "query_length=%d\n" (String.length query);
  Printf.printf "limit=%s\n" (match limit with None -> "all" | Some value -> string_of_int value);
  Printf.printf "matching_count=%d\n" full.stats.candidates_matched;
  Printf.printf "full_matching_time_seconds=%.6f\n" full.stats.matching_time;
  Printf.printf "full_ranking_time_seconds=%.6f\n" full.stats.ranking_time;
  Printf.printf "incremental_matching_time_seconds=%.6f\n" incremental.matching_time;
  Printf.printf "incremental_ranking_time_seconds=%.6f\n" incremental.ranking_time;
  Printf.printf "candidate_reduction_ratio=%.6f\n" reduction;
  Printf.printf "cache_hits=%d\n" incremental.cache_hits;
  Printf.printf "cache_misses=%d\n" incremental.cache_misses;
  Printf.printf "incremental_reuse=%d\n" incremental.incremental_reuse_count
