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

let assert_equal_string message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %S, got %S" message expected actual)

let starts_with ~prefix value =
  let prefix_length = String.length prefix in
  String.length value >= prefix_length
  && String.sub value 0 prefix_length = prefix

let ends_with ~suffix value =
  let suffix_length = String.length suffix in
  let value_length = String.length value in
  value_length >= suffix_length
  && String.sub value (value_length - suffix_length) suffix_length = suffix

let contains_substring ~needle value =
  let needle_length = String.length needle in
  let value_length = String.length value in
  let rec loop index =
    if needle_length = 0 then true
    else if index + needle_length > value_length then false
    else if String.sub value index needle_length = needle then true
    else loop (index + 1)
  in
  loop 0

let assert_contains message ~needle value =
  if not (contains_substring ~needle value) then
    failwith (Printf.sprintf "%s: expected %S to contain %S" message value needle)

let assert_not_contains message ~needle value =
  if contains_substring ~needle value then
    failwith (Printf.sprintf "%s: expected %S not to contain %S" message value needle)

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
    { query = ""; limit = None; mode = Interactive; preview = false; preview_position = Preview_right };
  assert_cli_ok "parse query" [ "ofzf"; "abc" ]
    { query = "abc"; limit = None; mode = Search; preview = false; preview_position = Preview_right };
  assert_cli_ok "parse limit" [ "ofzf"; "--limit"; "2"; "abc" ]
    { query = "abc"; limit = Some 2; mode = Search; preview = false; preview_position = Preview_right };
  assert_cli_ok "parse zero limit" [ "ofzf"; "--limit"; "0"; "abc" ]
    { query = "abc"; limit = Some 0; mode = Search; preview = false; preview_position = Preview_right };
  assert_cli_ok "parse bench" [ "ofzf"; "--bench"; "abc" ]
    { query = "abc"; limit = None; mode = Bench; preview = false; preview_position = Preview_right };
  assert_cli_ok "parse bench with limit" [ "ofzf"; "--bench"; "--limit"; "2"; "abc" ]
    { query = "abc"; limit = Some 2; mode = Bench; preview = false; preview_position = Preview_right };
  assert_cli_error "bench missing query" [ "ofzf"; "--bench" ];
  assert_cli_error "limit missing query" [ "ofzf"; "--limit"; "2" ];
  assert_cli_error "invalid limit" [ "ofzf"; "--limit"; "wat"; "abc" ];
  assert_cli_error "negative limit" [ "ofzf"; "--limit"; "-1"; "abc" ];

  assert_cli_ok "parse preview interactive with query" [ "ofzf"; "--preview"; "abc" ]
    { query = "abc"; limit = None; mode = Interactive; preview = true; preview_position = Preview_right };
  assert_cli_ok "parse preview right" [ "ofzf"; "--preview"; "--preview-position"; "right"; "abc" ]
    { query = "abc"; limit = None; mode = Interactive; preview = true; preview_position = Preview_right };
  assert_cli_ok "parse preview bottom" [ "ofzf"; "--preview"; "--preview-position"; "bottom"; "abc" ]
    { query = "abc"; limit = None; mode = Interactive; preview = true; preview_position = Preview_bottom };
  assert_cli_error "invalid preview position" [ "ofzf"; "--preview"; "--preview-position"; "side"; "abc" ];

  assert_equal_key "parse arrow up" Ofzf.Terminal.Arrow_up
    (Ofzf.Terminal.parse_key_sequence "\027[A");
  assert_equal_key "parse arrow down" Ofzf.Terminal.Arrow_down
    (Ofzf.Terminal.parse_key_sequence "\027[B");
  assert_equal_key "parse backspace" Ofzf.Terminal.Backspace
    (Ofzf.Terminal.parse_key_sequence "\127");
  assert_equal_key "parse ctrl-u" Ofzf.Terminal.Ctrl_u
    (Ofzf.Terminal.parse_key_sequence "\021");
  assert_equal_key "parse ctrl-w" Ofzf.Terminal.Ctrl_w
    (Ofzf.Terminal.parse_key_sequence "\023");
  assert_equal_key "parse ctrl-c" Ofzf.Terminal.Ctrl_c
    (Ofzf.Terminal.parse_key_sequence "\003");
  assert_equal_key "parse enter" Ofzf.Terminal.Enter
    (Ofzf.Terminal.parse_key_sequence "\r");
  assert_equal_key "parse escape" Ofzf.Terminal.Escape
    (Ofzf.Terminal.parse_key_sequence "\027");
  assert_equal_key "parse character" (Ofzf.Terminal.Character 'a')
    (Ofzf.Terminal.parse_key_sequence "a");
  assert_equal_key "parse unknown escape sequence" (Ofzf.Terminal.Unknown "\027[Z")
    (Ofzf.Terminal.parse_key_sequence "\027[Z");
  assert_equal_key "parse unknown long escape sequence"
    (Ofzf.Terminal.Unknown "\027[1;5A")
    (Ofzf.Terminal.parse_key_sequence "\027[1;5A");

  let normalized =
    Ofzf.Terminal.normalize_size
      ~fallback:{ Ofzf.Terminal.rows = 24; cols = 100 }
      { Ofzf.Terminal.rows = 0; cols = -1 }
  in
  assert_true "terminal size normalization falls back for bad rows"
    (normalized.rows = 24);
  assert_true "terminal size normalization falls back for bad cols"
    (normalized.cols = 100);

  assert_true "parse preview position right" (Ofzf.Preview.parse_position "right" = Some Ofzf.Preview.Right);
  assert_true "parse preview position bottom" (Ofzf.Preview.parse_position "bottom" = Some Ofzf.Preview.Bottom);
  assert_true "parse invalid preview position" (Ofzf.Preview.parse_position "side" = None);
  let right_layout = Ofzf.Preview.compute_layout ~terminal_rows:20 ~terminal_cols:80 ~preview:true ~position:Ofzf.Preview.Right in
  assert_true "right preview layout enabled" right_layout.enabled;
  assert_true "right preview has preview rect" (right_layout.preview <> None);
  assert_true "right preview preserves result columns" (right_layout.results.cols >= Ofzf.Preview.min_result_cols);
  let bottom_layout = Ofzf.Preview.compute_layout ~terminal_rows:24 ~terminal_cols:80 ~preview:true ~position:Ofzf.Preview.Bottom in
  assert_true "bottom preview layout enabled" bottom_layout.enabled;
  assert_true "bottom preview preserves result rows" (bottom_layout.results.rows >= Ofzf.Preview.min_result_rows);
  let tiny_layout = Ofzf.Preview.compute_layout ~terminal_rows:4 ~terminal_cols:20 ~preview:true ~position:Ofzf.Preview.Right in
  assert_true "tiny preview layout falls back to no preview" (not tiny_layout.enabled);
  let no_preview_layout = Ofzf.Preview.compute_layout ~terminal_rows:20 ~terminal_cols:80 ~preview:false ~position:Ofzf.Preview.Right in
  assert_true "no preview layout disabled" (not no_preview_layout.enabled);
  assert_equal_string_list "no selected preview message"
    [ "preview: no selected result" ]
    (Ofzf.Preview.render_preview_lines ~terminal_width:80 ~selected:None);
  assert_equal_string_list "selected preview renders candidate"
    [ "preview: selected candidate"; "matcher.ml" ]
    (Ofzf.Preview.render_preview_lines ~terminal_width:80 ~selected:(Some "matcher.ml"));
  assert_equal_string_list "selected preview clips long text"
    [ "preview:"; "matcher." ]
    (Ofzf.Preview.render_preview_lines ~terminal_width:8 ~selected:(Some "matcher.ml"));

  assert_true "ASCII display width uses one column per character"
    (Ofzf.Text_width.display_width "matcher" = 7);
  assert_true "tab display width uses configured tab width"
    (Ofzf.Text_width.display_width "a\tb" = 6);
  assert_true "basic UTF-8 display width is decoded safely"
    (Ofzf.Text_width.display_width "café" = 4);
  assert_true "combining marks are zero-width where practical"
    (Ofzf.Text_width.display_width "e\204\129" = 1);
  assert_true "wide CJK characters use two columns"
    (Ofzf.Text_width.display_width "界" = 2);
  assert_true "emoji fallback uses two columns"
    (Ofzf.Text_width.display_width "😀" = 2);
  assert_equal_string "invalid UTF-8 is represented safely" "�"
    (Ofzf.Text_width.sanitize "\192");
  assert_equal_string "width clipping keeps whole UTF-8 characters" "é"
    (Ofzf.Text_width.clip ~width:1 "éx");
  assert_equal_string "too-narrow clipping omits wide characters" ""
    (Ofzf.Text_width.clip ~width:1 "界x");
  assert_equal_string "wide character clipping includes full glyph" "界"
    (Ofzf.Text_width.clip ~width:2 "界x");
  assert_true "display width until byte respects decoded cells"
    (Ofzf.Text_width.display_width_until_byte ~byte_index:(String.length "a界")
       "a界b"
    = 3);
  assert_true "byte index for display column returns UTF-8 boundary"
    (Ofzf.Text_width.byte_index_for_display_column ~column:2 "a界b" = 1);

  let prompt_view =
    Ofzf.Interactive.render_prompt ~cursor_byte:(String.length "abcdef")
      ~terminal_width:6 ~query:"abcdef"
  in
  assert_equal_string "long prompt keeps cursor-side query text visible" "> cdef"
    prompt_view.visible;
  assert_true "long prompt cursor column stays within terminal width"
    (prompt_view.cursor_col = 5);
  let utf8_prompt =
    Ofzf.Interactive.render_prompt ~cursor_byte:(String.length "a界b")
      ~terminal_width:20 ~query:"a界b"
  in
  assert_equal_string "UTF-8 prompt renders safely" "> a界b" utf8_prompt.visible;
  assert_true "UTF-8 prompt cursor column uses display width"
    (utf8_prompt.cursor_col = 6);

  assert_true "interactive result rows leaves room for prompt"
    (Ofzf.Interactive.result_rows ~terminal_height:20 = 18);
  assert_true "interactive result rows handles tiny terminals"
    (Ofzf.Interactive.result_rows ~terminal_height:1 = 0);
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
  assert_true "arrow up at top stays at top"
    (Ofzf.Interactive.apply_key_to_selection Ofzf.Terminal.Arrow_up ~selected:0
       ~result_count:3
    = 0);
  assert_true "arrow down at bottom stays at bottom"
    (Ofzf.Interactive.apply_key_to_selection Ofzf.Terminal.Arrow_down
       ~selected:2 ~result_count:3
    = 2);
  assert_true "visible window handles no results"
    (Ofzf.Interactive.visible_window ~selected:0 ~terminal_height:6
       ~result_count:0
    = (0, 0));
  assert_true "visible window handles one result"
    (Ofzf.Interactive.visible_window ~selected:0 ~terminal_height:6
       ~result_count:1
    = (0, 1));
  assert_true "visible window keeps top selection visible"
    (Ofzf.Interactive.visible_window ~selected:0 ~terminal_height:5
       ~result_count:10
    = (0, 3));
  assert_true "visible window keeps bottom selection visible"
    (Ofzf.Interactive.visible_window ~selected:9 ~terminal_height:5
       ~result_count:10
    = (7, 10));
  assert_true "visible window handles fewer results than rows"
    (Ofzf.Interactive.visible_window ~selected:1 ~terminal_height:10
       ~result_count:3
    = (0, 3));
  assert_true "visible window keeps selected row visible"
    (Ofzf.Interactive.visible_window ~selected:7 ~terminal_height:6
       ~result_count:10
    = (4, 8));
  assert_true "visible window recalculates after tall resize"
    (Ofzf.Interactive.visible_window ~selected:8 ~terminal_height:10
       ~result_count:20
    = (1, 9));
  assert_true "visible window recalculates after short resize"
    (Ofzf.Interactive.visible_window ~selected:8 ~terminal_height:4
       ~result_count:20
    = (7, 9));
  assert_true "selection clamps after result shrink"
    (Ofzf.Interactive.clamp_selection ~selected:5 ~result_count:2 = 1);
  assert_true "visible window handles too-small terminal"
    (Ofzf.Interactive.visible_window ~selected:1 ~terminal_height:1
       ~result_count:3
    = (0, 0));
  assert_true "character edits query"
    (Ofzf.Interactive.apply_key_to_query (Ofzf.Terminal.Character 'm')
       ~query:""
    = "m");
  assert_true "backspace edits query"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Backspace ~query:"mat"
    = "ma");
  assert_true "backspace on empty query is safe"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Backspace ~query:"" = "");
  assert_true "ctrl-u clears query"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Ctrl_u ~query:"matcher"
    = "");
  assert_true "ctrl-w deletes previous word"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Ctrl_w
       ~query:"matcher fuzzy"
    = "matcher ");
  assert_true "ctrl-w removes trailing separators and previous word"
    (Ofzf.Interactive.delete_previous_word "matcher fuzzy   " = "matcher ");
  assert_true "unknown escape sequence does not edit query"
    (Ofzf.Interactive.apply_key_to_query (Ofzf.Terminal.Unknown "\027[Z")
       ~query:"mat"
    = "mat");
  assert_true "non-editing key keeps query"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Arrow_down ~query:"mat"
    = "mat");

  assert_equal_string "plain row clipping uses terminal width" "match"
    (Ofzf.Interactive.clip_plain ~terminal_width:5 "matcher.ml");
  assert_equal_string "zero-width clipping returns empty" ""
    (Ofzf.Interactive.clip_plain ~terminal_width:0 "matcher.ml");

  assert_equal_string "status includes count and selection"
    "3 matches · 2/3 selected · ↑/↓ move · Enter select · Esc cancel"
    (Ofzf.Interactive.format_status ~preview:false ~result_count:3 ~selected:1);
  assert_equal_string "status handles no results"
    "0 matches · no selection · ↑/↓ move · Enter select · Esc cancel"
    (Ofzf.Interactive.format_status ~preview:false ~result_count:0 ~selected:0);
  assert_equal_string "empty results message includes query"
    "(no matches for \"zzz\")"
    (Ofzf.Interactive.empty_results_message ~query:"zzz");

  let highlight_result = require_match "mat" "matcher.ml" in
  let highlighted =
    Ofzf.Interactive.render_candidate ~selected:false
      ~positions:highlight_result.positions ~candidate:highlight_result.candidate
  in
  assert_contains "normal row uses highlight style" ~needle:Ofzf.Terminal.highlight
    highlighted;
  assert_contains "normal row closes highlight style"
    ~needle:Ofzf.Terminal.end_highlight highlighted;
  let clipped_highlight =
    Ofzf.Interactive.render_candidate_clipped ~terminal_width:2 ~selected:false
      ~positions:highlight_result.positions ~candidate:highlight_result.candidate
  in
  assert_contains "clipped highlight preserves visible match style"
    ~needle:Ofzf.Terminal.highlight clipped_highlight;
  assert_not_contains "clipped highlight omits hidden text" ~needle:"t"
    clipped_highlight;
  let selected_line = Ofzf.Interactive.render_result_line ~selected:true highlight_result in
  assert_true "selected row starts inverse"
    (starts_with ~prefix:Ofzf.Terminal.inverse selected_line);
  assert_true "selected row resets styling"
    (ends_with ~suffix:Ofzf.Terminal.reset selected_line);
  assert_contains "selected highlight restores inverse"
    ~needle:Ofzf.Terminal.selected_end_highlight selected_line;
  let clipped_selected_line =
    Ofzf.Interactive.render_result_line ~terminal_width:3 ~selected:true
      highlight_result
  in
  assert_true "clipped selected row starts inverse"
    (starts_with ~prefix:Ofzf.Terminal.inverse clipped_selected_line);
  assert_true "clipped selected row resets styling"
    (ends_with ~suffix:Ofzf.Terminal.reset clipped_selected_line);

  let unicode_result =
    Ofzf.Matcher.{ candidate = "a界b"; positions = [ 0; String.length "a界" ]; score = 0 }
  in
  let unicode_clipped =
    Ofzf.Interactive.render_candidate_clipped ~terminal_width:3 ~selected:false
      ~positions:unicode_result.positions ~candidate:unicode_result.candidate
  in
  assert_contains "UTF-8 clipped row keeps whole visible glyph" ~needle:"界"
    unicode_clipped;
  assert_not_contains "UTF-8 clipped row omits hidden match" ~needle:"b"
    unicode_clipped;
  let unicode_selected =
    Ofzf.Interactive.render_result_line ~terminal_width:4 ~selected:true
      unicode_result
  in
  assert_true "UTF-8 selected clipped row starts inverse"
    (starts_with ~prefix:Ofzf.Terminal.inverse unicode_selected);
  assert_true "UTF-8 selected clipped row resets styling"
    (ends_with ~suffix:Ofzf.Terminal.reset unicode_selected);

  let render_lines =
    Ofzf.Interactive.render_lines ~terminal_height:4 ~query:"mat" ~selected:1
      [ require_match "mat" "matcher.ml"; require_match "mat" "src/matcher.ml" ]
  in
  assert_true "render line count respects terminal height" (List.length render_lines = 4);
  assert_contains "render status includes selected index" ~needle:"2/2 selected"
    (List.nth render_lines 1);
  let clipped_lines =
    Ofzf.Interactive.render_lines ~terminal_height:3 ~terminal_width:5
      ~query:"matcher" ~selected:0 [ highlight_result ]
  in
  assert_equal_string "prompt is clipped to terminal width" "> her"
    (List.hd clipped_lines);
  let empty_lines =
    Ofzf.Interactive.render_lines ~terminal_height:3 ~query:"zzz" ~selected:0 []
  in
  assert_equal_string_list "empty result render lines"
    [ "> zzz";
      "0 matches · no selection · ↑/↓ move · Enter select · Esc cancel";
      "(no matches for \"zzz\")" ]
    empty_lines;

  let preview_lines =
    Ofzf.Interactive.render_lines ~terminal_height:8 ~terminal_width:80 ~preview:true
      ~preview_position:Ofzf.Preview.Right ~query:"mat" ~selected:0
      [ highlight_result ]
  in
  assert_contains "interactive preview status marks preview" ~needle:"preview"
    (List.nth preview_lines 1);
  assert_true "interactive preview renders border or candidate"
    (List.exists (contains_substring ~needle:"preview:") preview_lines);
  let bottom_preview_lines =
    Ofzf.Interactive.render_lines ~terminal_height:12 ~terminal_width:80 ~preview:true
      ~preview_position:Ofzf.Preview.Bottom ~query:"mat" ~selected:0
      [ highlight_result ]
  in
  assert_true "bottom preview includes preview pane"
    (List.exists (contains_substring ~needle:"preview:") bottom_preview_lines);
  let empty_preview_lines =
    Ofzf.Interactive.render_lines ~terminal_height:8 ~terminal_width:80 ~preview:true
      ~query:"zzz" ~selected:0 []
  in
  assert_true "empty preview shows no selected message"
    (List.exists (contains_substring ~needle:"no selected result") empty_preview_lines);

  let none_selected, none_code = Ofzf.Interactive.selected_result ~selected:0 [] in
  assert_true "enter with no result has no selected output" (none_selected = None);
  assert_true "enter with no result exits non-zero" (none_code = 1);
  let some_selected, some_code =
    Ofzf.Interactive.selected_result ~selected:0 [ highlight_result ]
  in
  assert_true "enter with a result selects it" (some_selected = Some highlight_result);
  assert_true "enter with a result exits successfully" (some_code = 0);

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
