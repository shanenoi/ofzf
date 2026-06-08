let assert_equal_string message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %S, got %S" message expected actual)

let assert_equal_int message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %d, got %d" message expected actual)

let () =
  let open Ofzf.Query_edit in
  let inserted_beginning = make ~cursor:0 "at" |> apply (Insert 'm') in
  assert_equal_string "insert at beginning" "mat" (query inserted_beginning);
  assert_equal_int "insert at beginning advances cursor" 1 (cursor inserted_beginning);

  let inserted = make ~cursor:1 "mt" |> apply (Insert 'a') in
  assert_equal_string "insert at cursor" "mat" (query inserted);
  assert_equal_int "insert advances cursor" 2 (cursor inserted);

  let inserted_end = make "ma" |> apply (Insert 't') in
  assert_equal_string "insert at end" "mat" (query inserted_end);
  assert_equal_int "insert at end advances cursor" 3 (cursor inserted_end);

  let left = make "mat" |> apply Move_left in
  assert_equal_int "move left" 2 (cursor left);
  let right = left |> apply Move_right in
  assert_equal_int "move right" 3 (cursor right);
  assert_equal_int "home moves to start" 0 (make "mat" |> apply Move_start |> cursor);
  assert_equal_int "end moves to end" 3 (make ~cursor:0 "mat" |> apply Move_end |> cursor);

  let backspaced = make ~cursor:2 "mat" |> apply Backspace in
  assert_equal_string "backspace before cursor" "mt" (query backspaced);
  assert_equal_int "backspace moves cursor" 1 (cursor backspaced);

  let backspace_start = make ~cursor:0 "mat" |> apply Backspace in
  assert_equal_string "backspace at start leaves query" "mat" (query backspace_start);
  assert_equal_int "backspace at start leaves cursor" 0 (cursor backspace_start);

  let deleted = make ~cursor:1 "mat" |> apply Delete in
  assert_equal_string "delete at cursor" "mt" (query deleted);
  assert_equal_int "delete keeps cursor" 1 (cursor deleted);

  let delete_end = make "mat" |> apply Delete in
  assert_equal_string "delete at end leaves query" "mat" (query delete_end);
  assert_equal_int "delete at end leaves cursor" 3 (cursor delete_end);

  assert_equal_string "ctrl-u clears" "" (make "matcher" |> apply Clear |> query);
  assert_equal_string "ctrl-w deletes previous word" "matcher "
    (make "matcher fuzzy" |> apply Delete_previous_word |> query);
  let delete_word_middle = make ~cursor:7 "matcher fuzzy" |> apply Delete_previous_word in
  assert_equal_string "ctrl-w in middle deletes previous word" " fuzzy" (query delete_word_middle);
  assert_equal_int "ctrl-w in middle updates cursor" 0 (cursor delete_word_middle);
  assert_equal_string "append backspace empty safe" ""
    (apply_append_action Backspace ~query:"");
  assert_equal_int "cursor clamps low" 0 (clamp_cursor "abc" (-10));
  assert_equal_int "cursor clamps high" 3 (clamp_cursor "abc" 99);
  assert_equal_int "cursor clamps into utf8 boundary" 1 (clamp_cursor "a界b" 2);

  let unicode = "a界b" in
  let moved = make ~cursor:(String.length unicode) unicode |> apply Move_left in
  assert_equal_int "move-left respects utf8 boundary" (String.length "a界") (cursor moved);
  let removed = make ~cursor:(String.length "a界") unicode |> apply Backspace in
  assert_equal_string "backspace removes full utf8 cell" "ab" (query removed)
