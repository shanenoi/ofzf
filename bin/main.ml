let print_usage_error program error =
  prerr_endline (Ofzf.Cli.error_message program error)

let mode_to_string = function
  | Ofzf.Cli.Search -> "search"
  | Ofzf.Cli.Bench -> "bench"
  | Ofzf.Cli.Interactive -> "interactive"

let log_config (config : Ofzf.Cli.config) =
  Ofzf.Debug.logf "mode=%s query_length=%d limit=%s preview=%b"
    (mode_to_string config.mode)
    (String.length config.query)
    (match config.limit with None -> "none" | Some limit -> string_of_int limit)
    config.preview

let scored_item original_index (result : Ofzf.Matcher.match_result) =
  Ofzf.Topk.{ value = result; score = result.score; original_index }

let output_result item = print_endline item.Ofzf.Topk.value.Ofzf.Matcher.candidate

let read_all_stdin () =
  let rec loop acc =
    match input_line stdin with
    | line -> loop (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  loop []

let run_full query =
  let prepared_query = Ofzf.Matcher.prepare_query query in
  let rec loop index matches =
    match input_line stdin with
    | line -> (
        match Ofzf.Matcher.match_prepared ~query:prepared_query ~candidate:line with
        | None -> loop (index + 1) matches
        | Some result -> loop (index + 1) (scored_item index result :: matches))
    | exception End_of_file ->
        Ofzf.Debug.logf "search scanned=%d matched=%d" index (List.length matches);
        matches |> List.sort Ofzf.Topk.compare |> List.iter output_result
  in
  loop 0 []

let run_limited query limit =
  let prepared_query = Ofzf.Matcher.prepare_query query in
  let rec loop index best =
    match input_line stdin with
    | line -> (
        match Ofzf.Matcher.match_prepared ~query:prepared_query ~candidate:line with
        | None -> loop (index + 1) best
        | Some result ->
            loop (index + 1) (Ofzf.Topk.add ~k:limit best (scored_item index result)))
    | exception End_of_file ->
        Ofzf.Debug.logf "limited-search scanned=%d retained=%d limit=%d" index
          (List.length best) limit;
        List.iter output_result best
  in
  loop 0 []

let prefixes query =
  let rec loop length acc =
    if length > String.length query then List.rev acc
    else loop (length + 1) (String.sub query 0 length :: acc)
  in
  if query = "" then [ "" ] else loop 1 []

let run_bench query limit =
  let candidates = read_all_stdin () in
  let full = Ofzf.Search_engine.full_search ?limit ~query candidates in
  let final_incremental =
    List.fold_left
      (fun context prefix ->
        let result = Ofzf.Search_engine.incremental_search ?limit ~context ~query:prefix candidates in
        result.context)
      Ofzf.Search_engine.empty_context (prefixes query)
  in
  let incremental_stats = Ofzf.Search_engine.context_stats final_incremental in
  Ofzf.Debug.logf
    "bench candidates=%d matched=%d cache_hits=%d cache_misses=%d reuse=%d"
    (List.length candidates) full.stats.candidates_matched incremental_stats.cache_hits
    incremental_stats.cache_misses incremental_stats.incremental_reuse_count;
  Printf.printf "query=%s\n" query;
  Printf.printf "candidate_count=%d\n" (List.length candidates);
  Printf.printf "matched_count=%d\n" full.stats.candidates_matched;
  Printf.printf "matching_time_seconds=%.6f\n" full.stats.matching_time;
  Printf.printf "ranking_time_seconds=%.6f\n" full.stats.ranking_time;
  Printf.printf "cache_hits=%d\n" incremental_stats.cache_hits;
  Printf.printf "cache_misses=%d\n" incremental_stats.cache_misses;
  Printf.printf "incremental_reuse=%d\n" incremental_stats.incremental_reuse_count;
  Printf.printf "incremental_scanned=%d\n" incremental_stats.candidate_count_scanned;
  let reduction =
    if List.length candidates = 0 then 0.0
    else 1.0 -. (float_of_int incremental_stats.candidate_count_scanned /. float_of_int (List.length candidates))
  in
  Printf.printf "candidate_reduction_ratio=%.6f\n" reduction

let () =
  let program = if Array.length Sys.argv = 0 then "ofzf" else Sys.argv.(0) in
  match Ofzf.Cli.parse Sys.argv with
  | Error error ->
      print_usage_error program error;
      exit 2
  | Ok ({ mode = Interactive; query; preview; preview_position; _ } as config) ->
      log_config config;
      let candidates = read_all_stdin () in
      Ofzf.Debug.logf "interactive candidates=%d" (List.length candidates);
      let preview_position =
        match preview_position with
        | Ofzf.Cli.Preview_right -> Ofzf.Preview.Right
        | Ofzf.Cli.Preview_bottom -> Ofzf.Preview.Bottom
      in
      exit (Ofzf.Interactive.run ~preview ~preview_position ~initial_query:query ~candidates)
  | Ok ({ query; limit; mode = Bench; _ } as config) ->
      log_config config;
      run_bench query limit
  | Ok ({ query; limit = Some 0; mode = Search; _ } as config) ->
      log_config config;
      ignore query
  | Ok ({ query; limit = Some limit; mode = Search; _ } as config) ->
      log_config config;
      run_limited query limit
  | Ok ({ query; limit = None; mode = Search; _ } as config) ->
      log_config config;
      run_full query
