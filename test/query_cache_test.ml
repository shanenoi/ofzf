open Test_support

let () =
  let cache = Ofzf.Query_cache.empty in
  assert_true "cache miss" (Ofzf.Query_cache.find ~query:"mat" cache = None);
  let cache = Ofzf.Query_cache.add ~query:"ma" ~results:[ "matcher.ml" ] cache in
  assert_true "cache lookup" (Ofzf.Query_cache.find ~query:"ma" cache = Some [ "matcher.ml" ]);
  assert_true "prefix relationship" (Ofzf.Query_cache.is_prefix ~prefix:"ma" ~query:"mat");
  assert_true "non-prefix relationship rejected" (not (Ofzf.Query_cache.is_prefix ~prefix:"mt" ~query:"mat"));
  let bounded = Ofzf.Query_cache.create ~max_entries:2 () in
  let bounded = Ofzf.Query_cache.add ~query:"a" ~results:[ "a" ] bounded in
  let bounded = Ofzf.Query_cache.add ~query:"ab" ~results:[ "ab" ] bounded in
  let bounded = Ofzf.Query_cache.add ~query:"abc" ~results:[ "abc" ] bounded in
  assert_true "oldest entry evicted" (Ofzf.Query_cache.find ~query:"a" bounded = None);
  assert_true "newest entry retained" (Ofzf.Query_cache.find ~query:"abc" bounded = Some [ "abc" ]);
  (match Ofzf.Query_cache.longest_prefix ~query:"abcd" bounded with
  | Some entry -> assert_equal_string "longest prefix" "abc" entry.Ofzf.Query_cache.query
  | None -> failwith "longest prefix: expected an entry");
  let disabled = Ofzf.Query_cache.create ~max_entries:0 () in
  let disabled = Ofzf.Query_cache.add ~query:"a" ~results:[ "a" ] disabled in
  assert_true "zero-entry cache stores nothing" (Ofzf.Query_cache.entries disabled = [])
