open Test_support

let () =
  assert_true "case-insensitive match" (Ofzf.Matcher.matches ~query:"OF" "src/ofzf.ml");
  assert_true "non-matching candidate rejected"
    (not (Ofzf.Matcher.matches ~query:"zz" "src/ofzf.ml"));
  let result = require_match "fz" "FuzzyZero" in
  assert_equal_int_list "match positions" [ 0; 2 ] result.positions;
  assert_equal_string_list "ranking correctness"
    [ "abc.txt"; "a_bc"; "a_b_c.txt"; "src/abc.txt"; "later-abc.txt" ]
    (ranked_candidates "abc"
       [ "later-abc.txt"; "a_b_c.txt"; "src/abc.txt"; "abc.txt"; "a_bc" ]);
  assert_equal_string_list "stable sorting preserves input order on ties"
    [ "same"; "same"; "same" ]
    (ranked_candidates "sam" [ "same"; "same"; "same" ]);
  let highlighted = require_match "mat" "matcher.ml" in
  assert_equal_int_list "match positions available for highlighting" [ 0; 1; 2 ]
    highlighted.positions
