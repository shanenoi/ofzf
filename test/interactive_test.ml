open Test_support

let () =
  assert_true "parse arrow up" (Ofzf.Terminal.parse_key_sequence "\027[A" = Ofzf.Terminal.Arrow_up);
  assert_true "parse arrow down" (Ofzf.Terminal.parse_key_sequence "\027[B" = Ofzf.Terminal.Arrow_down);
  assert_true "parse arrow left" (Ofzf.Terminal.parse_key_sequence "\027[D" = Ofzf.Terminal.Arrow_left);
  assert_true "parse arrow right" (Ofzf.Terminal.parse_key_sequence "\027[C" = Ofzf.Terminal.Arrow_right);
  assert_true "parse home" (Ofzf.Terminal.parse_key_sequence "\027[H" = Ofzf.Terminal.Home);
  assert_true "parse end" (Ofzf.Terminal.parse_key_sequence "\027[F" = Ofzf.Terminal.End);
  assert_true "parse delete" (Ofzf.Terminal.parse_key_sequence "\027[3~" = Ofzf.Terminal.Delete);
  assert_true "parse backspace" (Ofzf.Terminal.parse_key_sequence "\127" = Ofzf.Terminal.Backspace);
  assert_true "parse ctrl-a" (Ofzf.Terminal.parse_key_sequence "\001" = Ofzf.Terminal.Ctrl_a);
  assert_true "parse ctrl-u" (Ofzf.Terminal.parse_key_sequence "\021" = Ofzf.Terminal.Ctrl_u);
  assert_true "parse ctrl-w" (Ofzf.Terminal.parse_key_sequence "\023" = Ofzf.Terminal.Ctrl_w);
  assert_true "parse ctrl-b" (Ofzf.Terminal.parse_key_sequence "\002" = Ofzf.Terminal.Ctrl_b);
  assert_true "parse ctrl-f" (Ofzf.Terminal.parse_key_sequence "\006" = Ofzf.Terminal.Ctrl_f);
  assert_true "parse page up" (Ofzf.Terminal.parse_key_sequence "\027[5~" = Ofzf.Terminal.Page_up);
  assert_true "parse page down" (Ofzf.Terminal.parse_key_sequence "\027[6~" = Ofzf.Terminal.Page_down);
  assert_true "parse unknown escape" (Ofzf.Terminal.parse_key_sequence "\027[Z" = Ofzf.Terminal.Unknown "\027[Z");
  let normalized =
    Ofzf.Terminal.normalize_size ~fallback:{ Ofzf.Terminal.rows = 24; cols = 100 }
      { Ofzf.Terminal.rows = 0; cols = -1 }
  in
  assert_equal_int "terminal size fallback rows" 24 normalized.rows;
  assert_equal_int "terminal size fallback cols" 100 normalized.cols;
  assert_equal_int "result rows leaves room for prompt" 18 (Ofzf.Interactive.result_rows ~terminal_height:20);
  assert_equal_int "result rows tiny terminal" 0 (Ofzf.Interactive.result_rows ~terminal_height:1);
  assert_equal_string "character edits query" "m"
    (Ofzf.Interactive.apply_key_to_query (Ofzf.Terminal.Character 'm') ~query:"");
  assert_equal_string "space edits query in single-select editing" "ab "
    (Ofzf.Interactive.apply_key_to_query (Ofzf.Terminal.Character ' ') ~query:"ab");
  assert_equal_string "backspace edits query" "ma"
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Backspace ~query:"mat");
  assert_equal_string "backspace empty query safe" ""
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Backspace ~query:"");
  assert_equal_string "ctrl-u clears query" ""
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Ctrl_u ~query:"matcher");
  assert_equal_string "ctrl-w deletes previous word" "matcher "
    (Ofzf.Interactive.apply_key_to_query Ofzf.Terminal.Ctrl_w ~query:"matcher fuzzy");
  assert_equal_string "unknown escape ignores query" "mat"
    (Ofzf.Interactive.apply_key_to_query (Ofzf.Terminal.Unknown "\027[Z") ~query:"mat");
  let open Ofzf.Query_edit in
  let edit = make ~cursor:1 "mt" in
  let edited = Ofzf.Interactive.apply_key_to_query_edit (Ofzf.Terminal.Character 'a') edit in
  assert_equal_string "interactive insert at cursor" "mat" (query edited);
  assert_equal_int "interactive insert advances cursor" 2 (cursor edited);
  let moved = Ofzf.Interactive.apply_key_to_query_edit Ofzf.Terminal.Arrow_left edited in
  assert_equal_string "interactive arrow-left preserves query" "mat" (query moved);
  assert_equal_int "interactive arrow-left moves cursor" 1 (cursor moved);
  let deleted = Ofzf.Interactive.apply_key_to_query_edit Ofzf.Terminal.Delete moved in
  assert_equal_string "interactive delete at cursor" "mt" (query deleted);
  assert_equal_int "interactive delete keeps cursor" 1 (cursor deleted);
  let start = Ofzf.Interactive.apply_key_to_query_edit Ofzf.Terminal.Ctrl_a edited in
  assert_equal_int "interactive ctrl-a moves start" 0 (cursor start);
  let finish = Ofzf.Interactive.apply_key_to_query_edit Ofzf.Terminal.Ctrl_e start in
  assert_equal_int "interactive ctrl-e moves end" 3 (cursor finish);
  assert_equal_int "preview line down delta" 1
    (Option.get (Ofzf.Interactive.preview_scroll_delta ~visible_rows:5 Ofzf.Terminal.Ctrl_e));
  assert_equal_int "preview page down delta" 5
    (Option.get (Ofzf.Interactive.preview_scroll_delta ~visible_rows:5 Ofzf.Terminal.Ctrl_f));
  let none_selected, none_code = Ofzf.Interactive.selected_result ~selected:0 [] in
  assert_true "enter with no result has no selected output" (none_selected = None);
  assert_equal_int "enter with no result exits non-zero" 1 none_code;
  let result = require_match "mat" "matcher.ml" in
  let some_selected, some_code = Ofzf.Interactive.selected_result ~selected:0 [ result ] in
  assert_true "enter with result selects it" (some_selected = Some result);
  assert_equal_int "enter with result exits successfully" 0 some_code;
  assert_equal_string_list "interactive toggles candidate selection" [ "help" ]
    (Ofzf.Interactive.toggle_candidate_selection ~candidates:[ "hello"; "help" ]
       ~candidate:"help" ~marked:[]);
  assert_equal_string_list "interactive multi enter falls back to highlighted" [ "matcher.ml" ]
    (fst
       (Ofzf.Interactive.selected_candidate_outputs ~candidates:[ "matcher.ml" ] ~marked:[]
          ~selected:0 [ result ]))
