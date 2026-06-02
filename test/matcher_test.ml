let assert_true message value = if not value then failwith message

let assert_equal_int_list message expected actual =
  if expected <> actual then
    failwith
      (Printf.sprintf "%s: expected [%s], got [%s]" message
         (String.concat "; " (List.map string_of_int expected))
         (String.concat "; " (List.map string_of_int actual)))

let assert_equal_string_list message expected actual =
  if expected <> actual then
    failwith
      (Printf.sprintf "%s: expected [%s], got [%s]" message
         (String.concat "; " expected) (String.concat "; " actual))

let assert_greater message left right =
  if left <= right then
    failwith (Printf.sprintf "%s: expected %d > %d" message left right)

let require_match query candidate =
  match Ofzf.Matcher.match_candidate ~query ~candidate with
  | Some result -> result
  | None -> failwith (Printf.sprintf "expected %S to match %S" candidate query)

let ranked_candidates query candidates =
  Ofzf.Matcher.rank ~query candidates
  |> List.map (fun result -> result.Ofzf.Matcher.candidate)

let () =
  assert_true "case-insensitive match"
    (Ofzf.Matcher.matches ~query:"OF" "src/ofzf.ml");

  assert_true "non-matching candidate rejected"
    (not (Ofzf.Matcher.matches ~query:"zz" "src/ofzf.ml"));

  let result = require_match "fz" "FuzzyZero" in
  assert_equal_int_list "match positions" [ 0; 2 ] result.positions;

  let tight = require_match "abc" "abc.txt" in
  let loose = require_match "abc" "a_b_c.txt" in
  assert_greater "consecutive matches score higher" tight.score loose.score;

  let boundary = require_match "mat" "src/Matcher.ml" in
  let embedded = require_match "mat" "src/rematcher.ml" in
  assert_greater "CamelCase boundary scores higher" boundary.score embedded.score;

  let slash_boundary = require_match "mat" "src/matcher.ml" in
  let late_embedded = require_match "mat" "src/prematcher.ml" in
  assert_greater "slash boundary scores higher" slash_boundary.score
    late_embedded.score;

  let underscore_boundary = require_match "mat" "src/x_matcher.ml" in
  let underscore_embedded = require_match "mat" "src/xmatcher.ml" in
  assert_greater "underscore boundary scores higher" underscore_boundary.score
    underscore_embedded.score;

  let bullet_boundary = require_match "mat" "src/●matcher.ml" in
  let bullet_embedded = require_match "mat" "src/prematcher.ml" in
  assert_greater "bullet boundary scores higher" bullet_boundary.score
    bullet_embedded.score;

  let early = require_match "abc" "abc-later.txt" in
  let late = require_match "abc" "later-abc.txt" in
  assert_greater "early match scores higher" early.score late.score;

  let short = require_match "abc" "abc.txt" in
  let long = require_match "abc" "abc-very-long-file-name.txt" in
  assert_greater "shorter candidate scores higher" short.score long.score;

  assert_equal_string_list "ranking correctness"
    [ "abc.txt"; "a_b_c.txt"; "src/abc.txt"; "later-abc.txt" ]
    (ranked_candidates "abc"
       [ "later-abc.txt"; "a_b_c.txt"; "src/abc.txt"; "abc.txt" ]);

  assert_equal_string_list "stable sorting preserves original order on ties"
    [ "same"; "same"; "same" ]
    (ranked_candidates "sam" [ "same"; "same"; "same" ]);

  assert_equal_string_list "stable sorting does not alphabetize ties"
    [ "aby"; "abx" ] (ranked_candidates "ab" [ "aby"; "abx" ])
