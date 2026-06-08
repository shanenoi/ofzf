let assert_true message value = if not value then failwith message
let assert_equal_int message expected actual =
  if expected <> actual then failwith (Printf.sprintf "%s: expected %d, got %d" message expected actual)

let assert_equal_string_list message expected actual =
  if expected <> actual then
    failwith
      (Printf.sprintf "%s: expected [%s], got [%s]" message
         (String.concat "; " expected) (String.concat "; " actual))

let assert_equal_int_list message expected actual =
  if expected <> actual then
    failwith
      (Printf.sprintf "%s: expected [%s], got [%s]" message
         (String.concat "; " (List.map string_of_int expected))
         (String.concat "; " (List.map string_of_int actual)))

let result ?(original_index = 0) candidate =
  Ofzf.Matcher.{ candidate; original_index; positions = []; score = 0 }

let () =
  let open Ofzf.Selection in
  assert_equal_int "clamp no results" 0 (clamp ~selected:9 ~result_count:0);
  assert_equal_int "clamp top" 0 (clamp ~selected:(-1) ~result_count:3);
  assert_equal_int "clamp bottom" 2 (clamp ~selected:9 ~result_count:3);
  assert_equal_int "move down" 2 (apply_action Move_down ~selected:1 ~result_count:3);
  assert_equal_int "move down bottom" 2 (apply_action Move_down ~selected:2 ~result_count:3);
  assert_equal_int "move page down" 5 (apply_action ~page_size:4 Page_down ~selected:1 ~result_count:9);
  assert_equal_int "move page up" 1 (apply_action ~page_size:4 Page_up ~selected:5 ~result_count:9);
  let results =
    [ result ~original_index:0 "a"; result ~original_index:1 "b"; result ~original_index:2 "c" ]
  in
  assert_equal_int "preserve selected candidate by id" 1
    (preserve_selected_candidate_id ~previous_candidate_id:(Some 1) ~fallback_selected:0 results);
  assert_equal_int "fallback clamp after missing candidate" 2
    (preserve_selected_candidate_id ~previous_candidate_id:(Some 99) ~fallback_selected:9 results);
  let selected, code = selected_result ~selected:0 [] in
  assert_true "no result selected" (selected = None && code = 1);
  assert_true "candidate marked" (candidate_marked ~marked_candidate_ids:[ 1 ] ~candidate_id:1);
  assert_true "candidate not marked" (not (candidate_marked ~marked_candidate_ids:[ 1 ] ~candidate_id:0));
  assert_equal_int_list "toggle adds in input order" [ 1 ]
    (toggle_candidate_id ~candidate_id:1 ~marked_candidate_ids:[]);
  assert_equal_int_list "toggle second preserves input order" [ 0; 1 ]
    (toggle_candidate_id ~candidate_id:0 ~marked_candidate_ids:[ 1 ]);
  assert_equal_int_list "toggle removes" []
    (toggle_candidate_id ~candidate_id:1 ~marked_candidate_ids:[ 1 ]);
  assert_equal_string_list "marks drop candidates missing from full input" [ "b" ]
    (marked_candidates_in_input_order ~candidates:[ "a"; "b"; "c" ] ~marked_candidate_ids:[ 99; 1 ]);
  assert_equal_string_list "duplicate candidate text keeps separate ids" [ "dup"; "dup" ]
    (marked_candidates_in_input_order ~candidates:[ "dup"; "other"; "dup" ] ~marked_candidate_ids:[ 2; 0 ]);
  let outputs, output_code =
    selected_candidate_outputs ~candidates:[ "a"; "b"; "c" ] ~marked_candidate_ids:[ 2; 0 ]
      ~selected:1 results
  in
  assert_equal_string_list "marked outputs are stable input order" [ "a"; "c" ] outputs;
  assert_equal_int "marked outputs exit success" 0 output_code;
  let fallback_outputs, fallback_code =
    selected_candidate_outputs ~candidates:[ "a"; "b"; "c" ] ~marked_candidate_ids:[] ~selected:1 results
  in
  assert_equal_string_list "empty marked falls back to highlighted" [ "b" ] fallback_outputs;
  assert_equal_int "fallback exits success" 0 fallback_code
