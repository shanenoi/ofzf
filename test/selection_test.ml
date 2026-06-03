let assert_true message value = if not value then failwith message
let assert_equal_int message expected actual =
  if expected <> actual then failwith (Printf.sprintf "%s: expected %d, got %d" message expected actual)

let result candidate = Ofzf.Matcher.{ candidate; positions = []; score = 0 }

let () =
  let open Ofzf.Selection in
  assert_equal_int "clamp no results" 0 (clamp ~selected:9 ~result_count:0);
  assert_equal_int "clamp top" 0 (clamp ~selected:(-1) ~result_count:3);
  assert_equal_int "clamp bottom" 2 (clamp ~selected:9 ~result_count:3);
  assert_equal_int "move down" 2 (apply_action Move_down ~selected:1 ~result_count:3);
  assert_equal_int "move down bottom" 2 (apply_action Move_down ~selected:2 ~result_count:3);
  assert_equal_int "move page down" 5 (apply_action ~page_size:4 Page_down ~selected:1 ~result_count:9);
  assert_equal_int "move page up" 1 (apply_action ~page_size:4 Page_up ~selected:5 ~result_count:9);
  let results = [ result "a"; result "b"; result "c" ] in
  assert_equal_int "preserve selected candidate" 1
    (preserve_selected_candidate ~previous_candidate:(Some "b") ~fallback_selected:0 results);
  assert_equal_int "fallback clamp after missing candidate" 2
    (preserve_selected_candidate ~previous_candidate:(Some "z") ~fallback_selected:9 results);
  let selected, code = selected_result ~selected:0 [] in
  assert_true "no result selected" (selected = None && code = 1)
