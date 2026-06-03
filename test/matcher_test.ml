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

let assert_equal_key message expected actual =
  if expected <> actual then failwith (message ^ ": unexpected key")

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
  assert_cli_ok "parse interactive mode" [ "ofzf" ]
    { query = ""; limit = None; mode = Interactive };
  assert_cli_ok "parse query" [ "ofzf"; "abc" ]
    { query = "abc"; limit = None; mode = Search };
  assert_cli_ok "parse limit" [ "ofzf"; "--limit"; "2"; "abc" ]
    { query = "abc"; limit = Some 2; mode = Search };
  assert_cli_ok "parse zero limit" [ "ofzf"; "--limit"; "0"; "abc" ]
    { query = "abc"; limit = Some 0; mode = Search };
  assert_cli_ok "parse bench" [ "ofzf"; "--bench"; "abc" ]
    { query = "abc"; limit = None; mode = Bench };
  assert_cli_ok "parse bench with limit" [ "ofzf"; "--bench"; "--limit"; "2"; "abc" ]
    { query = "abc"; limit = Some 2; mode = Bench };
  assert_cli_error "bench missing query" [ "ofzf"; "--bench" ];
  assert_cli_error "limit missing query" [ "ofzf"; "--limit"; "2" ];
  assert_cli_error "invalid limit" [ "ofzf"; "--limit"; "wat"; "abc" ];
  assert_cli_error "negative limit" [ "ofzf"; "--limit"; "-1"; "abc" ];

  assert_equal_key "parse arrow up" Ofzf.Terminal.Arrow_up
    (Ofzf.Terminal.parse_key_sequence "\027[A");
  assert_equal_key "parse arrow down" Ofzf.Terminal.Arrow_down
    (Ofzf.Terminal.parse_key_sequence "\027[B");
  assert_equal_key "parse backspace" Ofzf.Terminal.Backspace
    (Ofzf.Terminal.parse_key_sequence "\127");
  assert_equal_key "parse ctrl-c" Ofzf.Terminal.Ctrl_c
    (Ofzf.Terminal.parse_key_sequence "\003");
  assert_equal_key "parse enter" Ofzf.Terminal.Enter
    (Ofzf.Terminal.parse_key_sequence "\r");
  assert_equal_key "parse escape" Ofzf.Terminal.Escape
    (Ofzf.Terminal.parse_key_sequence "\027");
  assert_equal_key "parse character" (Ofzf.Terminal.Character 'a')
    (Ofzf.Terminal.parse_key_sequence "a");

  assert_true "interactive result rows leaves room for prompt"
    (Ofzf.Interactive.result_rows ~terminal_height:20 = 17);
  assert_true "interactive result rows has safe minimum"
    (Ofzf.Interactive.result_rows ~terminal_height:1 = 1);
  assert_true "selection clamps empty result set"
    (Ofzf.Interactive.clamp_selection ~selected:10 ~result_count:0 = 0);
  assert_true "selection clamps high values"
    (Ofzf.Interactive.clamp_selection ~selected:10 ~result_count:3 = 2);
  assert_true "selection clamps low values"
    (Ofzf.Interactive.clamp_selection ~selected:(-1) ~result_count:3 = 0);
  assert_true "arrow down moves selection"
    (Ofzf.Interactive.apply_key_to_selection Ofzf.Terminal.Arrow_down
       ~selected:0 ~result_count:3
    = 1);
  assert_true "arrow up moves selection"
    (Ofzf.Interactive.apply_key_to_selection Ofzf.Terminal.Arrow_up ~selected:1
       ~result_count:3
    = 0);
  assert_true "visible window keeps selected row visible"
    (Ofzf.Interactive.visible_window ~selected:7 ~terminal_height:6
       ~result_count:10
    = (5, 8));
  assert_true "character edits query"
    (Ofzf.Interactive.apply_key_to_query (Ofzf.Terminal.Character 'm')
       ~query:""
    = "m");
  assert_true "backspace edits query"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Backspace ~query:"mat"
    = "ma");
  assert_true "non-editing key keeps query"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Arrow_down ~query:"mat"
    = "mat");

  let cache = Ofzf.Query_cache.empty in
  assert_true "cache miss" (Ofzf.Query_cache.find ~query:"mat" cache = None);
  let cache = Ofzf.Query_cache.add ~query:"ma" ~results:[ "matcher.ml" ] cache in
  assert_true "cache lookup"
    (Ofzf.Query_cache.find ~query:"ma" cache = Some [ "matcher.ml" ]);
  assert_true "prefix relationship"
    (Ofzf.Query_cache.is_prefix ~prefix:"ma" ~query:"mat");
  assert_true "non-prefix relationship rejected"
    (not (Ofzf.Query_cache.is_prefix ~prefix:"mt" ~query:"mat"));

  let candidates =
    [ "matcher.ml"; "src/matcher.ml"; "scoring.ml"; "README.md"; "mat" ]
  in
  let full = Ofzf.Search_engine.full_search ~query:"mat" candidates in
  assert_equal_string_list "full search correctness"
    (ranked_candidates "mat" candidates)
    (List.map (fun result -> result.Ofzf.Matcher.candidate) full.results);
  assert_true "full search scans all candidates"
    (full.stats.candidate_count_scanned = List.length candidates);
  assert_true "full search records cache miss" (full.stats.cache_misses = 1);

  let first =
    Ofzf.Search_engine.incremental_search
      ~context:Ofzf.Search_engine.empty_context ~query:"m" candidates
  in
  let second =
    Ofzf.Search_engine.incremental_search ~context:first.context ~query:"ma"
      candidates
  in
  let third =
    Ofzf.Search_engine.incremental_search ~context:second.context ~query:"mat"
      candidates
  in
  assert_true "incremental reuse recorded"
    (third.stats.incremental_reuse_count >= 2);
  assert_true "incremental scans subset"
    (third.stats.candidate_count_scanned <= List.length candidates);
  assert_equal_string_list "incremental ranking consistency"
    (ranked_candidates "mat" candidates)
    (List.map (fun result -> result.Ofzf.Matcher.candidate) third.results);

  let fallback =
    Ofzf.Search_engine.incremental_search ~context:third.context ~query:"sc"
      candidates
  in
  assert_true "fallback scans full input"
    (fallback.stats.candidate_count_scanned = List.length candidates);
  assert_true "fallback records cache miss" (fallback.stats.cache_misses >= 1);

  let repeated =
    Ofzf.Search_engine.incremental_search ~context:third.context ~query:"mat"
      candidates
  in
  assert_true "exact query cache hit" (repeated.stats.cache_hits >= 1);
  assert_true "cache hit scans no candidates"
    (repeated.stats.candidate_count_scanned = 0)
