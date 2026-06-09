open Test_support

let () =
  assert_true "parse preview right" (Ofzf.Preview.parse_position "right" = Some Ofzf.Preview.Right);
  assert_true "parse preview bottom" (Ofzf.Preview.parse_position "bottom" = Some Ofzf.Preview.Bottom);
  assert_true "parse invalid preview position" (Ofzf.Preview.parse_position "side" = None);
  let right = Ofzf.Preview.compute_layout ~terminal_rows:20 ~terminal_cols:80 ~preview:true ~position:Ofzf.Preview.Right in
  assert_true "right preview layout enabled" right.enabled;
  assert_true "right preview has preview rect" (right.preview <> None);
  let bottom = Ofzf.Preview.compute_layout ~terminal_rows:24 ~terminal_cols:80 ~preview:true ~position:Ofzf.Preview.Bottom in
  assert_true "bottom preview layout enabled" bottom.enabled;
  let tiny = Ofzf.Preview.compute_layout ~terminal_rows:4 ~terminal_cols:20 ~preview:true ~position:Ofzf.Preview.Right in
  assert_true "tiny preview falls back" (not tiny.enabled);
  assert_equal_string_list "no selection preview"
    [ "preview: no selected result" ]
    (Ofzf.Preview.render_preview_lines ~terminal_width:80 ~selected:None);
  assert_equal_string_list "plain candidate preview"
    [ "preview: text: candidate text"; "plain candidate text" ]
    (Ofzf.Preview.render_preview_lines ~terminal_width:80 ~selected:(Some "plain candidate text"));
  assert_equal_string_list "preview clips long text" [ "preview:"; "matcher " ]
    (Ofzf.Preview.render_preview_lines ~terminal_width:8 ~selected:(Some "matcher text"));
  assert_equal_int "scroll clamps high" 7 (Ofzf.Preview.clamp_scroll ~scroll:100 ~line_count:10 ~visible_rows:3);
  assert_equal_int "scroll clamps low" 0 (Ofzf.Preview.clamp_scroll ~scroll:(-2) ~line_count:10 ~visible_rows:3);
  assert_equal_int "scroll clamps empty" 0 (Ofzf.Preview.clamp_scroll ~scroll:4 ~line_count:0 ~visible_rows:3);

  let unicode_file = fixture "unicode-đường-dẫn.txt" in
  let crlf_file = fixture "crlf.txt" in
  let binary_file = fixture "binary_like.bin" in
  let directory = fixture "preview_dir" in
  let missing = missing_fixture "missing-file.txt" in
  (match Ofzf.Preview.classify_candidate unicode_file with
  | Ofzf.Preview.Regular_file_path path -> assert_equal_string "unicode file classification" unicode_file path
  | _ -> failwith "unicode file classification: unexpected kind");
  (match Ofzf.Preview.classify_candidate directory with
  | Ofzf.Preview.Directory_path path -> assert_equal_string "directory classification" directory path
  | _ -> failwith "directory classification: unexpected kind");
  (match Ofzf.Preview.classify_candidate missing with
  | Ofzf.Preview.Missing_path_value path -> assert_equal_string "missing classification" missing path
  | _ -> failwith "missing classification: unexpected kind");
  let file_content = Ofzf.Preview.content_for_selection ~max_bytes:Ofzf.Preview.max_preview_bytes (Some crlf_file) in
  assert_true "regular file content kind" (file_content.kind = Ofzf.Preview.Regular_file);
  assert_equal_string_list "CRLF normalization" [ "line1"; "line2"; "line3" ] file_content.lines;
  let limited = Ofzf.Preview.content_for_selection ~max_bytes:3 (Some crlf_file) in
  assert_true "max preview bytes truncates" limited.truncated;
  let binary = Ofzf.Preview.content_for_selection ~max_bytes:Ofzf.Preview.max_preview_bytes (Some binary_file) in
  assert_true "binary-looking content kind" (binary.kind = Ofzf.Preview.Binary_file);
  assert_true "binary content not logged/rendered" (List.exists (contains ~needle:"binary-looking") binary.lines);
  let command_echo =
    Ofzf.Preview.content_for_selection ~source:(Ofzf.Preview.command_source "echo")
      ~max_bytes:Ofzf.Preview.max_preview_bytes (Some "hello; echo unsafe")
  in
  assert_true "command preview stdout kind" (command_echo.kind = Ofzf.Preview.Command_output);
  assert_equal_string_list "command preview passes candidate as argv"
    [ "hello; echo unsafe" ] command_echo.lines;
  assert_not_contains "command preview does not shell-expand candidate" ~needle:"unsafe\nunsafe"
    (String.concat "\n" command_echo.lines);
  let command_empty =
    Ofzf.Preview.content_for_selection ~source:(Ofzf.Preview.command_source "true")
      ~max_bytes:Ofzf.Preview.max_preview_bytes (Some "ignored")
  in
  assert_true "empty command output kind" (command_empty.kind = Ofzf.Preview.Command_output);
  assert_contains "empty command output message" ~needle:"produced no output"
    (String.concat "\n" command_empty.lines);
  let command_failure =
    Ofzf.Preview.content_for_selection ~source:(Ofzf.Preview.command_source "false")
      ~max_bytes:Ofzf.Preview.max_preview_bytes (Some "ignored")
  in
  assert_true "non-zero command output kind" (command_failure.kind = Ofzf.Preview.Command_error);
  assert_contains "non-zero command status" ~needle:"exited with status"
    (String.concat "\n" command_failure.lines);
  with_temp_dir (fun dir ->
      let stderr_script = Filename.concat dir "stderr-preview" in
      write_file stderr_script "#!/bin/sh\nprintf '%s\\n' \"$1\" >&2\n";
      Unix.chmod stderr_script 0o700;
      let command_stderr =
        Ofzf.Preview.content_for_selection ~source:(Ofzf.Preview.command_source stderr_script)
          ~max_bytes:Ofzf.Preview.max_preview_bytes (Some "stderr only")
      in
      assert_true "successful stderr command is output content"
        (command_stderr.kind = Ofzf.Preview.Command_output);
      assert_contains "successful stderr is labeled" ~needle:"wrote stderr"
        (String.concat "\n" command_stderr.lines);
      assert_contains "successful stderr is captured" ~needle:"stderr only"
        (String.concat "\n" command_stderr.lines));
  let command_missing =
    Ofzf.Preview.content_for_selection
      ~source:(Ofzf.Preview.command_source "ofzf-preview-command-that-does-not-exist")
      ~max_bytes:Ofzf.Preview.max_preview_bytes (Some "ignored")
  in
  assert_true "missing command output kind" (command_missing.kind = Ofzf.Preview.Command_error);
  assert_contains "missing command message" ~needle:"not found"
    (String.concat "\n" command_missing.lines);
  let command_timeout =
    Ofzf.Preview.content_for_selection ~source:(Ofzf.Preview.command_source "sleep")
      ~max_bytes:Ofzf.Preview.max_preview_bytes (Some "2")
  in
  assert_true "timeout command output kind" (command_timeout.kind = Ofzf.Preview.Command_error);
  assert_contains "timeout command message" ~needle:"timed out"
    (String.concat "\n" command_timeout.lines);
  with_temp_dir (fun dir ->
      let large_path = Filename.concat dir "large.txt" in
      write_file large_path "abcdef\n";
      let command_truncated =
        Ofzf.Preview.content_for_selection ~source:(Ofzf.Preview.command_source "cat")
          ~max_bytes:3 (Some large_path)
      in
      assert_true "command output truncates" command_truncated.truncated;
      assert_contains "command truncation notice" ~needle:"truncated"
        (String.concat "\n" command_truncated.lines));
  let clipped =
    Ofzf.Preview.render_content_lines ~terminal_width:3 ~height:3 ~scroll:0
      { Ofzf.Preview.kind = Ofzf.Preview.Regular_file; title = "unicode"; lines = [ "界abc" ]; truncated = false }
  in
  assert_equal_string "preview clips Unicode" "界a" (List.nth clipped 1);
  assert_contains "preview title includes source" ~needle:"preview: file"
    (Ofzf.Preview.format_title ~scroll:0 ~visible_rows:3 file_content)
