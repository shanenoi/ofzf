open Test_support

let () =
  let open Ofzf.Preview_state in
  assert_true "initial no selection" (default.selected_candidate = None);
  let loads = ref 0 in
  let loader ~source:_ selected =
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
  let source_changed = update ~source:(Ofzf.Preview.command_source "echo") ~loader changed (Some "beta") in
  assert_true "changed source reloads" (!loads = 3);
  assert_true "changed source is stored" (source_changed.source = Ofzf.Preview.command_source "echo");
  assert_true "scroll delta line" (scroll_delta ~visible_rows:3 Ofzf.Terminal.Ctrl_e = Some 1);
  assert_true "scroll delta page" (scroll_delta ~visible_rows:3 Ofzf.Terminal.Ctrl_f = Some 3);

  let directory = update default (Some (fixture "preview_dir")) in
  assert_true "directory content loaded" (directory.content.kind = Ofzf.Preview.Directory);
  let missing = update default (Some (missing_fixture "missing-file.txt")) in
  assert_true "missing content loaded" (missing.content.kind = Ofzf.Preview.Missing_path);
  let plain = update default (Some "plain text candidate") in
  assert_true "plain fallback content loaded" (plain.content.kind = Ofzf.Preview.Candidate_text);
  let binary = update default (Some (fixture "binary_like.bin")) in
  assert_true "binary-looking content loaded" (binary.content.kind = Ofzf.Preview.Binary_file)
