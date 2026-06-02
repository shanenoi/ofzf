let assert_true message value =
  if not value then failwith message

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

let require_match query candidate =
  match Ofzf.Matcher.match_candidate ~query ~candidate with
  | Some result -> result
  | None -> failwith (Printf.sprintf "expected %S to match %S" candidate query)

let () =
  assert_true "case-insensitive match"
    (Ofzf.Matcher.matches ~query:"OF" "src/ofzf.ml");

  assert_true "non-matching candidate rejected"
    (not (Ofzf.Matcher.matches ~query:"zz" "src/ofzf.ml"));

  let result = require_match "fz" "FuzzyZero" in
  assert_equal_int_list "match positions" [ 0; 2 ] result.positions;

  let ranked =
    Ofzf.Matcher.rank ~query:"of"
      [ "docs/ofzf.md"; "other-file"; "src/matcher.ml"; "ofzf" ]
    |> List.map (fun result -> result.Ofzf.Matcher.candidate)
  in
  assert_equal_string_list "ranked matching lines"
    [ "ofzf"; "other-file"; "docs/ofzf.md" ] ranked
