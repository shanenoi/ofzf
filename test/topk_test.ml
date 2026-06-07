open Test_support

let item value score original_index = Ofzf.Topk.{ value; score; original_index }

let item_values items = List.map (fun item -> item.Ofzf.Topk.value) items

let heap_values ~k items =
  let heap = Ofzf.Topk.create ~k () in
  List.iter (Ofzf.Topk.push heap) items;
  item_values (Ofzf.Topk.to_sorted_list heap)

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
  let sorted = Ofzf.Topk.of_list ~k:10 [ item "late" 10 2; item "early" 10 1 ] in
  assert_equal_string_list "top-k stable ordering"
    [ "early"; "late" ] (item_values sorted);

  let zero = Ofzf.Topk.create ~k:0 () in
  Ofzf.Topk.push zero (item "ignored" 100 0);
  assert_equal_int "heap k=0 retains nothing" 0 (Ofzf.Topk.length zero);
  assert_equal_string_list "heap k=0 returns empty" [] (item_values (Ofzf.Topk.to_sorted_list zero));

  assert_equal_string_list "heap k=1 keeps the best item" [ "best" ]
    (heap_values ~k:1 [ item "weak" 10 0; item "best" 20 1; item "weaker" 5 2 ]);

  let small_input = [ item "b" 20 2; item "a" 30 1; item "c" 10 3 ] in
  assert_equal_string_list "heap k larger than input sorts all retained items"
    [ "a"; "b"; "c" ] (heap_values ~k:10 small_input);

  assert_equal_string_list "heap preserves normal top-k ordering"
    [ "a"; "b"; "c" ]
    (heap_values ~k:3
       [ item "d" 40 4; item "b" 90 2; item "e" 30 5; item "a" 100 1; item "c" 80 3 ]);

  assert_equal_string_list "heap tie stability follows original input order"
    [ "early"; "middle"; "late" ]
    (heap_values ~k:3
       [ item "late" 50 3; item "early" 50 1; item "middle" 50 2 ]);

  assert_equal_string_list "heap replaces weakest retained item" [ "best"; "better" ]
    (heap_values ~k:2 [ item "weak" 10 1; item "better" 20 2; item "best" 30 3 ]);

  assert_equal_string_list "heap skips items not better than weakest" [ "best"; "kept" ]
    (heap_values ~k:2
       [ item "best" 100 0; item "kept" 90 1; item "worse" 80 2; item "equal-but-later" 90 2 ]);

  let representative =
    [
      item "a" 10 0;
      item "b" 50 1;
      item "c" 30 2;
      item "d" 50 3;
      item "e" 40 4;
      item "f" 10 5;
      item "g" 60 6;
    ]
  in
  assert_equal_string_list "heap top-k equals full-sort prefix"
    (representative |> List.sort Ofzf.Topk.compare |> take 4 |> item_values)
    (representative |> Ofzf.Topk.of_list ~k:4 |> item_values)
