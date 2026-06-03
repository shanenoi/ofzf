open Test_support

let () =
  assert_equal_string_list "top-k returns best two in rank order" [ "abc"; "a_bc" ]
    (ranked_top_candidates "abc" 2 [ "a___b___c"; "a_bc"; "abc"; "later-abc" ]);
  assert_equal_string_list "top-k preserves stable ties" [ "same"; "same" ]
    (ranked_top_candidates "sam" 2 [ "same"; "same"; "same" ]);
  assert_equal_string_list "top-k zero returns no matches" []
    (ranked_top_candidates "abc" 0 [ "abc" ]);
  let values = [ "a___b___c"; "src/abc"; "abc"; "sameabc"; "a_bc"; "abc-long" ] in
  assert_equal_string_list "top-k matches full ranking prefix" (take 3 (ranked_candidates "abc" values))
    (ranked_top_candidates "abc" 3 values);
  let item value score original_index = Ofzf.Topk.{ value; score; original_index } in
  let sorted = Ofzf.Topk.of_list ~k:10 [ item "late" 10 2; item "early" 10 1 ] in
  assert_equal_string_list "top-k stable ordering"
    [ "early"; "late" ] (List.map (fun item -> item.Ofzf.Topk.value) sorted)
