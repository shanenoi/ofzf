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

let ranked_top_candidates query k candidates =
  Ofzf.Matcher.rank_top ~query ~k candidates
  |> List.map (fun result -> result.Ofzf.Matcher.candidate)

let take count values =
  let rec loop remaining acc = function
    | _ when remaining <= 0 -> List.rev acc
    | [] -> List.rev acc
    | value :: rest -> loop (remaining - 1) (value :: acc) rest
  in
  loop count [] values

let assert_cli_ok message argv expected =
  match Ofzf.Cli.parse (Array.of_list argv) with
  | Ok actual when actual = expected -> ()
  | Ok _ -> failwith (message ^ ": parsed unexpected config")
  | Error _ -> failwith (message ^ ": expected parse success")

let assert_cli_error message argv =
  match Ofzf.Cli.parse (Array.of_list argv) with
  | Ok _ -> failwith (message ^ ": expected parse error")
  | Error _ -> ()

let score query candidate = (require_match query candidate).score

let () =
  assert_true "case-insensitive match"
    (Ofzf.Matcher.matches ~query:"OF" "src/ofzf.ml");

  assert_true "non-matching candidate rejected"
    (not (Ofzf.Matcher.matches ~query:"zz" "src/ofzf.ml"));

  let result = require_match "fz" "FuzzyZero" in
  assert_equal_int_list "match positions" [ 0; 2 ] result.positions;

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

  assert_greater "CamelCase boundary scores higher"
    (score "mat" "src/Matcher.ml")
    (score "mat" "src/rematcher.ml");

  assert_greater "slash boundary scores higher" (score "mat" "src/matcher.ml")
    (score "mat" "src/prematcher.ml");

  assert_greater "underscore boundary scores higher"
    (score "mat" "src/x_matcher.ml")
    (score "mat" "src/xmatcher.ml");

  assert_greater "bullet boundary scores higher" (score "mat" "src/●matcher.ml")
    (score "mat" "src/prematcher.ml");

  assert_greater "early match scores higher" (score "abc" "abc-later.txt")
    (score "abc" "later-abc.txt");

  assert_greater "shorter candidate scores higher" (score "abc" "abc.txt")
    (score "abc" "abc-very-long-file-name.txt");

  assert_equal_string_list "ranking correctness"
    [ "abc.txt"; "a_bc"; "a_b_c.txt"; "src/abc.txt"; "later-abc.txt" ]
    (ranked_candidates "abc"
       [ "later-abc.txt"; "a_b_c.txt"; "src/abc.txt"; "abc.txt"; "a_bc" ]);

  assert_equal_string_list "stable sorting preserves original order on ties"
    [ "same"; "same"; "same" ]
    (ranked_candidates "sam" [ "same"; "same"; "same" ]);

  assert_equal_string_list "stable sorting does not alphabetize ties"
    [ "aby"; "abx" ] (ranked_candidates "ab" [ "aby"; "abx" ]);

  assert_equal_string_list "top-k returns best two in rank order"
    [ "abc"; "a_bc" ]
    (ranked_top_candidates "abc" 2
       [ "a___b___c"; "a_bc"; "abc"; "later-abc" ]);

  assert_equal_string_list "top-k preserves stable ties"
    [ "same"; "same" ] (ranked_top_candidates "sam" 2 [ "same"; "same"; "same" ]);

  assert_equal_string_list "top-k zero returns no matches" []
    (ranked_top_candidates "abc" 0 [ "abc" ]);

  let full_rank =
    ranked_candidates "abc"
      [ "a___b___c"; "src/abc"; "abc"; "sameabc"; "a_bc"; "abc-long" ]
  in
  let top_three =
    ranked_top_candidates "abc" 3
      [ "a___b___c"; "src/abc"; "abc"; "sameabc"; "a_bc"; "abc-long" ]
  in
  assert_equal_string_list "top-k matches full ranking prefix"
    (take 3 full_rank) top_three;

  let open Ofzf.Cli in
  assert_cli_ok "parse query" [ "ofzf"; "abc" ] { query = "abc"; limit = None };
  assert_cli_ok "parse limit" [ "ofzf"; "--limit"; "2"; "abc" ]
    { query = "abc"; limit = Some 2 };
  assert_cli_ok "parse zero limit" [ "ofzf"; "--limit"; "0"; "abc" ]
    { query = "abc"; limit = Some 0 };
  assert_cli_error "missing query" [ "ofzf" ];
  assert_cli_error "invalid limit" [ "ofzf"; "--limit"; "wat"; "abc" ];
  assert_cli_error "negative limit" [ "ofzf"; "--limit"; "-1"; "abc" ]
