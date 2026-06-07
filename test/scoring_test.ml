open Test_support

let score query candidate = (require_match query candidate).score

let () =
  let prepared_query = Ofzf.Matcher.prepare_query "abc" in
  let prepared_match =
    match Ofzf.Matcher.match_prepared ~query:prepared_query ~candidate:"ABC.txt" with
    | Some result -> result
    | None -> failwith "expected prepared case-insensitive match"
  in
  assert_equal_int "prepared path keeps case-insensitive scoring"
    (score "abc" "ABC.txt") prepared_match.score;
  let scoring_query = Ofzf.Scoring.prepare_query "matcher" in
  let direct_score = score "matcher" "Matcher.ml" in
  let prepared_score =
    Ofzf.Scoring.score_prepared ~query:scoring_query ~candidate:"Matcher.ml"
      ~positions:[ 0; 1; 2; 3; 4; 5; 6 ]
  in
  assert_equal_int "prepared scoring matches public scoring" direct_score prepared_score;
  assert_greater "consecutive matches score higher" (score "abc" "abc.txt")
    (score "abc" "a_b_c.txt");
  assert_greater "gap penalty prefers no gap" (score "abc" "abc")
    (score "abc" "a_bc");
  assert_greater "gap penalty prefers smaller gap" (score "abc" "a_bc")
    (score "abc" "a___b___c");
  assert_greater "exact match beats extension" (score "matcher" "matcher")
    (score "matcher" "matcher.ml");
  assert_greater "prefix beats nested path" (score "mat" "matcher.ml")
    (score "mat" "src/matcher.ml");
  assert_greater "path-aware scoring prefers shallow basename"
    (score "matcher" "matcher.ml")
    (score "matcher" "src/fuzzy/matcher.ml");
  assert_greater "CamelCase boundary scores higher" (score "mat" "src/Matcher.ml")
    (score "mat" "src/rematcher.ml");
  assert_greater "slash boundary scores higher" (score "mat" "src/matcher.ml")
    (score "mat" "src/prematcher.ml");
  assert_greater "underscore boundary scores higher" (score "mat" "src/x_matcher.ml")
    (score "mat" "src/xmatcher.ml");
  assert_greater "bullet boundary scores higher" (score "mat" "src/●matcher.ml")
    (score "mat" "src/prematcher.ml");
  assert_greater "early match scores higher" (score "abc" "abc-later.txt")
    (score "abc" "later-abc.txt");
  assert_greater "shorter candidate scores higher" (score "abc" "abc.txt")
    (score "abc" "abc-very-long-file-name.txt")
