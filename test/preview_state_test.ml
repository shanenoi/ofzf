let assert_true message value = if not value then failwith message

let () =
  let open Ofzf.Preview_state in
  assert_true "initial no selection" (default.selected_candidate = None);
  let loads = ref 0 in
  let loader selected =
    incr loads;
    match selected with
    | None -> Ofzf.Preview.no_selection_content
    | Some value -> Ofzf.Preview.content_of_candidate_text value
  in
  let first = update ~loader default (Some "alpha") in
  let second = update ~loader first (Some "alpha") in
  assert_true "same candidate does not reload" (!loads = 1 && first = second);
  let scrolled = { second with scroll = 99 } |> clamp_scroll ~visible_rows:1 in
  assert_true "scroll clamp" (scrolled.scroll >= 0);
  let changed = update ~loader scrolled (Some "beta") in
  assert_true "changed candidate reloads" (!loads = 2);
  assert_true "changed candidate resets scroll" (changed.scroll = 0);
  assert_true "scroll delta line" (scroll_delta ~visible_rows:3 Ofzf.Terminal.Ctrl_e = Some 1);
  assert_true "scroll delta page" (scroll_delta ~visible_rows:3 Ofzf.Terminal.Ctrl_f = Some 3)
