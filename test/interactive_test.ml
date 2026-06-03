open Test_support

let () =
  assert_true "parse arrow up" (Ofzf.Terminal.parse_key_sequence "\027[A" = Ofzf.Terminal.Arrow_up);
  assert_true "parse arrow down" (Ofzf.Terminal.parse_key_sequence "\027[B" = Ofzf.Terminal.Arrow_down);
  assert_true "parse backspace" (Ofzf.Terminal.parse_key_sequence "\127" = Ofzf.Terminal.Backspace);
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
  assert_equal_int "enter with result exits successfully" 0 some_code
