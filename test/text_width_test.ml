open Test_support

let () =
  assert_equal_int "ASCII display width" 7 (Ofzf.Text_width.display_width "matcher");
  assert_equal_int "tab display width" 6 (Ofzf.Text_width.display_width "a\tb");
  assert_equal_int "basic UTF-8 width" 4 (Ofzf.Text_width.display_width "café");
  assert_equal_int "combining mark width" 1 (Ofzf.Text_width.display_width "e\204\129");
  assert_equal_int "wide CJK width" 2 (Ofzf.Text_width.display_width "界");
  assert_equal_int "emoji fallback width" 2 (Ofzf.Text_width.display_width "😀");
  assert_equal_string "invalid UTF-8 fallback" "�" (Ofzf.Text_width.sanitize "\192");
  assert_equal_string "width clipping keeps whole UTF-8" "é" (Ofzf.Text_width.clip ~width:1 "éx");
  assert_equal_string "too-narrow clipping omits wide character" "" (Ofzf.Text_width.clip ~width:1 "界x");
  assert_equal_string "wide clipping includes whole glyph" "界" (Ofzf.Text_width.clip ~width:2 "界x");
  assert_equal_int "display width until byte" 3
    (Ofzf.Text_width.display_width_until_byte ~byte_index:(String.length "a界") "a界b");
  assert_equal_int "byte index for display column" 1
    (Ofzf.Text_width.byte_index_for_display_column ~column:2 "a界b");
  assert_equal_string "ANSI stripping removes CSI" "match"
    (Ofzf.Text_width.strip_ansi (Ofzf.Terminal.inverse ^ "match" ^ Ofzf.Terminal.reset));
  assert_equal_int "ANSI display width ignores style bytes" 3
    (Ofzf.Text_width.display_width_ansi
       (Ofzf.Terminal.inverse ^ Ofzf.Terminal.highlight ^ "界a" ^ Ofzf.Terminal.reset));
  let prompt = Ofzf.Text_width.prompt_view ~terminal_width:6 ~cursor_byte:6 "abcdef" in
  assert_equal_string "prompt clipping" "> cdef" prompt.visible;
  assert_equal_int "prompt cursor column" 5 prompt.cursor_col
