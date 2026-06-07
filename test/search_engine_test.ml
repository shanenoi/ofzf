open Test_support

let candidates = [ "matcher.ml"; "src/matcher.ml"; "scoring.ml"; "README.md"; "mat" ]

let candidate_names results = List.map (fun result -> result.Ofzf.Matcher.candidate) results

let () =
  let full = Ofzf.Search_engine.full_search ~query:"mat" candidates in
  assert_equal_string_list "full search correctness" (ranked_candidates "mat" candidates)
    (candidate_names full.results);
  assert_equal_int "full search scans all candidates" (List.length candidates)
    full.stats.candidate_count_scanned;
  assert_equal_int "full search records cache miss" 1 full.stats.cache_misses;
  let limited = Ofzf.Search_engine.full_search ~limit:2 ~query:"mat" candidates in
  assert_equal_string_list "limited search matches ranking prefix"
    (take 2 (ranked_candidates "mat" candidates)) (candidate_names limited.results);
  let empty = Ofzf.Search_engine.full_search ~query:"" [ "bb"; "a"; "" ] in
  assert_equal_string_list "empty query keeps stable scoring semantics" [ ""; "a"; "bb" ]
    (candidate_names empty.results);
  let first = Ofzf.Search_engine.incremental_search ~context:Ofzf.Search_engine.empty_context ~query:"m" candidates in
  let second = Ofzf.Search_engine.incremental_search ~context:first.context ~query:"ma" candidates in
  let third = Ofzf.Search_engine.incremental_search ~context:second.context ~query:"mat" candidates in
  assert_true "incremental reuse recorded" (third.stats.incremental_reuse_count >= 2);
  assert_true "incremental scans subset" (third.stats.candidate_count_scanned <= List.length candidates);
  assert_equal_string_list "incremental ranking consistency" (ranked_candidates "mat" candidates)
    (candidate_names third.results);
  let fallback = Ofzf.Search_engine.incremental_search ~context:third.context ~query:"sc" candidates in
  assert_equal_int "fallback scans full input" (List.length candidates) fallback.stats.candidate_count_scanned;
  let repeated = Ofzf.Search_engine.incremental_search ~context:third.context ~query:"mat" candidates in
  assert_true "exact query cache hit" (repeated.stats.cache_hits >= 1);
  assert_equal_int "cache hit scans no candidates" 0 repeated.stats.candidate_count_scanned
