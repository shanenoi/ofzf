let assert_equal_pair message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: unexpected viewport" message)
let assert_true message value = if not value then failwith message

let () =
  let open Ofzf.Viewport in
  assert_true "result rows subtract headers" (result_rows ~terminal_height:20 = 18);
  assert_equal_pair "no results" (0, 0)
    (visible_window_for_rows ~selected:0 ~visible_rows:5 ~result_count:0);
  assert_equal_pair "one result" (0, 1)
    (visible_window_for_rows ~selected:0 ~visible_rows:5 ~result_count:1);
  assert_equal_pair "top visible" (0, 3)
    (visible_window_for_rows ~selected:0 ~visible_rows:3 ~result_count:10);
  assert_equal_pair "bottom visible" (7, 10)
    (visible_window_for_rows ~selected:9 ~visible_rows:3 ~result_count:10);
  let right_rows =
    result_visible_rows ~terminal_height:12 ~terminal_width:(Some 80) ~preview:true
      ~preview_position:Ofzf.Preview.Right
  in
  let bottom_rows =
    result_visible_rows ~terminal_height:12 ~terminal_width:(Some 80) ~preview:true
      ~preview_position:Ofzf.Preview.Bottom
  in
  assert_true "right preview has result rows" (right_rows > 0);
  assert_true "bottom preview reserves preview rows" (bottom_rows < result_rows ~terminal_height:12);
  let tiny =
    result_visible_rows ~terminal_height:3 ~terminal_width:(Some 8) ~preview:true
      ~preview_position:Ofzf.Preview.Right
  in
  assert_true "tiny terminal safe" (tiny >= 0)
