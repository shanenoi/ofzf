type stats = {
  candidate_count_scanned : int;
  candidates_matched : int;
  cache_hits : int;
  cache_misses : int;
  incremental_reuse_count : int;
  matching_time : float;
  ranking_time : float;
}

type indexed_candidate = {
  candidate : string;
  original_index : int;
}

type search_context = {
  previous_query : string option;
  previous_candidate_subset : indexed_candidate list;
  cache : indexed_candidate Query_cache.t;
  stats : stats;
}

type search_result = {
  query : string;
  results : Matcher.match_result list;
  context : search_context;
  stats : stats;
}

type matched_candidate = {
  result : Matcher.match_result;
  original_index : int;
}

let zero_stats = {
  candidate_count_scanned = 0;
  candidates_matched = 0;
  cache_hits = 0;
  cache_misses = 0;
  incremental_reuse_count = 0;
  matching_time = 0.0;
  ranking_time = 0.0;
}

let empty_context = {
  previous_query = None;
  previous_candidate_subset = [];
  cache = Query_cache.empty;
  stats = zero_stats;
}

let previous_query context = context.previous_query
let previous_candidate_subset context =
  List.map (fun candidate -> candidate.candidate) context.previous_candidate_subset
let context_stats (context : search_context) = context.stats

let time thunk =
  let start = Sys.time () in
  let value = thunk () in
  (value, Sys.time () -. start)

let add_stats base delta = {
  candidate_count_scanned = delta.candidate_count_scanned;
  candidates_matched = delta.candidates_matched;
  cache_hits = base.cache_hits + delta.cache_hits;
  cache_misses = base.cache_misses + delta.cache_misses;
  incremental_reuse_count = base.incremental_reuse_count + delta.incremental_reuse_count;
  matching_time = delta.matching_time;
  ranking_time = delta.ranking_time;
}

let indexed_candidates candidates =
  List.mapi (fun original_index candidate -> { candidate; original_index }) candidates

let match_source ~query source =
  let query = Matcher.prepare_query query in
  source
  |> List.filter_map (fun (source_candidate : indexed_candidate) ->
         match
           Matcher.match_prepared_indexed ~original_index:source_candidate.original_index ~query
             ~candidate:source_candidate.candidate
         with
         | None -> None
         | Some result -> Some { result; original_index = source_candidate.original_index })

let subset_of_matched matched =
  List.map
    (fun matched ->
      { candidate = matched.result.Matcher.candidate; original_index = matched.original_index })
    matched

let rank_matched ?limit matched =
  match limit with
  | Some k ->
      let best = Topk.create ~k () in
      matched
      |> List.iter (fun matched ->
             Topk.push best
               {
                 Topk.value = matched.result;
                 score = matched.result.Matcher.score;
                 original_index = matched.original_index;
               });
      best |> Topk.to_sorted_list |> List.map (fun item -> item.Topk.value)
  | None ->
      matched
      |> List.stable_sort (fun left right ->
             match compare right.result.Matcher.score left.result.Matcher.score with
             | 0 -> compare left.original_index right.original_index
             | by_score -> by_score)
      |> List.map (fun matched -> matched.result)

let search_from ~limit ~base_stats ~query ~source ~cache_hits ~cache_misses
    ~incremental_reuse_count =
  let scanned = List.length source in
  let matched, matching_time = time (fun () -> match_source ~query source) in
  let subset = subset_of_matched matched in
  let results, ranking_time = time (fun () -> rank_matched ?limit matched) in
  let delta = {
    candidate_count_scanned = scanned;
    candidates_matched = List.length subset;
    cache_hits;
    cache_misses;
    incremental_reuse_count;
    matching_time;
    ranking_time;
  } in
  let stats = add_stats base_stats delta in
  (subset, results, stats)

let make_result ~query ~subset ~results ~cache ~stats =
  let context = {
    previous_query = Some query;
    previous_candidate_subset = subset;
    cache = Query_cache.add ~query ~results:subset cache;
    stats;
  } in
  { query; results; context; stats }

let full_search ?limit ~query candidates =
  let source = indexed_candidates candidates in
  let subset, results, stats =
    search_from ~limit ~base_stats:zero_stats ~query ~source
      ~cache_hits:0 ~cache_misses:1 ~incremental_reuse_count:0
  in
  make_result ~query ~subset ~results ~cache:Query_cache.empty ~stats

let incremental_search ?limit ~context ~query candidates =
  match Query_cache.find ~query context.cache with
  | Some subset ->
      let matched, matching_time = time (fun () -> match_source ~query subset) in
      let results, ranking_time = time (fun () -> rank_matched ?limit matched) in
      let delta = {
        candidate_count_scanned = 0;
        candidates_matched = List.length subset;
        cache_hits = 1;
        cache_misses = 0;
        incremental_reuse_count = 0;
        matching_time;
        ranking_time;
      } in
      let stats = add_stats context.stats delta in
      make_result ~query ~subset ~results ~cache:context.cache ~stats
  | None ->
      let cache_source =
        match Query_cache.longest_prefix ~query context.cache with
        | Some (entry : indexed_candidate Query_cache.entry) when entry.Query_cache.query <> query ->
            Some entry.Query_cache.results
        | _ -> None
      in
      let previous_source =
        match context.previous_query with
        | Some previous when Query_cache.is_prefix ~prefix:previous ~query ->
            Some context.previous_candidate_subset
        | _ -> None
      in
      let source, reuse =
        match cache_source with
        | Some source -> (source, 1)
        | None -> (
            match previous_source with
            | Some source -> (source, 1)
            | None -> (indexed_candidates candidates, 0))
      in
      let subset, results, stats =
        search_from ~limit ~base_stats:context.stats ~query ~source ~cache_hits:0
          ~cache_misses:1 ~incremental_reuse_count:reuse
      in
      make_result ~query ~subset ~results ~cache:context.cache ~stats
