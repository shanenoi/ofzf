let assert_equal_string message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %S, got %S" message expected actual)

let assert_equal_int message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %d, got %d" message expected actual)

let () =
  let open Ofzf.Query_edit in
  let inserted = make ~cursor:1 "mt" |> apply (Insert 'a') in
  assert_equal_string "insert at cursor" "mat" (query inserted);
  assert_equal_int "insert advances cursor" 2 (cursor inserted);

  let backspaced = make ~cursor:2 "mat" |> apply Backspace in
  assert_equal_string "backspace before cursor" "mt" (query backspaced);
  assert_equal_int "backspace moves cursor" 1 (cursor backspaced);

  let deleted = make ~cursor:1 "mat" |> apply Delete in
  assert_equal_string "delete at cursor" "mt" (query deleted);
  assert_equal_int "delete keeps cursor" 1 (cursor deleted);

  assert_equal_string "ctrl-u clears" "" (make "matcher" |> apply Clear |> query);
  assert_equal_string "ctrl-w deletes previous word" "matcher "
    (make "matcher fuzzy" |> apply Delete_previous_word |> query);
  assert_equal_string "append backspace empty safe" ""
    (apply_append_action Backspace ~query:"");
  assert_equal_int "cursor clamps low" 0 (clamp_cursor "abc" (-10));
  assert_equal_int "cursor clamps high" 3 (clamp_cursor "abc" 99);

  let unicode = "a界b" in
  let moved = make ~cursor:(String.length unicode) unicode |> apply Move_left in
  assert_equal_int "move-left respects utf8 boundary" (String.length "a界") (cursor moved);
  let removed = make ~cursor:(String.length "a界") unicode |> apply Backspace in
  assert_equal_string "backspace removes full utf8 cell" "ab" (query removed)
