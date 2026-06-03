open Test_support

let input = "hello\nhelp\nworld\n"
let pipe_input command = "printf " ^ shell_quote input ^ " | " ^ command
let quote_bin bin = shell_quote bin

let assert_exit message expected result =
  assert_equal_int message expected (exit_code result.status)

let run_ofzf bin args = run_shell (pipe_input (quote_bin bin ^ " " ^ args))
let run_debug bin args =
  run_shell (pipe_input ("OFZF_DEBUG=1 " ^ quote_bin bin ^ " " ^ args))

let () =
  match ofzf_binary () with
  | None -> ()
  | Some bin ->
      let search = run_ofzf bin "he" in
      assert_exit "ofzf query exits zero" 0 search;
      assert_equal_string "ofzf query stdout" "help\nhello\n" search.stdout;
      assert_equal_string "debug disabled by default" "" search.stderr;

      let limited = run_ofzf bin "--limit 1 he" in
      assert_exit "ofzf limit exits zero" 0 limited;
      assert_equal_string "ofzf limit stdout" "help\n" limited.stdout;

      let bench = run_ofzf bin "--bench he" in
      assert_exit "ofzf bench exits zero" 0 bench;
      assert_contains "bench output includes query" ~needle:"query=he" bench.stdout;

      let bench_limit = run_ofzf bin "--bench --limit 1 he" in
      assert_exit "ofzf bench limit exits zero" 0 bench_limit;
      assert_contains "bench limit output includes query" ~needle:"query=he" bench_limit.stdout;

      let invalid_limit = run_ofzf bin "--limit nope he" in
      assert_true "invalid limit exits non-zero" (exit_code invalid_limit.status <> 0);
      assert_contains "invalid limit message" ~needle:"invalid --limit" invalid_limit.stderr;

      let invalid_preview = run_ofzf bin "--preview --preview-position side" in
      assert_true "invalid preview exits non-zero" (exit_code invalid_preview.status <> 0);
      assert_contains "invalid preview message" ~needle:"invalid --preview-position" invalid_preview.stderr;

      let missing_preview = run_ofzf bin "--preview-position right he" in
      assert_true "preview-position without preview exits non-zero" (exit_code missing_preview.status <> 0);
      assert_contains "preview-position without preview message" ~needle:"requires --preview" missing_preview.stderr;

      let bench_preview = run_ofzf bin "--bench --preview he" in
      let preview_bench = run_ofzf bin "--preview --bench he" in
      assert_true "bench preview exits non-zero" (exit_code bench_preview.status <> 0);
      assert_true "preview bench exits non-zero" (exit_code preview_bench.status <> 0);
      assert_equal_string "bench preview order-independent stderr" bench_preview.stderr preview_bench.stderr;

      let preview_limit = run_ofzf bin "--preview --limit 1 he" in
      assert_true "preview limit exits non-zero" (exit_code preview_limit.status <> 0);
      assert_contains "preview limit message" ~needle:"cannot be combined with --limit" preview_limit.stderr;

      let preview_right = run_ofzf bin "--preview --preview-position right" in
      assert_true "preview right non-tty exits non-zero" (exit_code preview_right.status <> 0);
      assert_contains "preview right terminal error" ~needle:"cannot start interactive terminal" preview_right.stderr;

      let preview_bottom = run_ofzf bin "--preview --preview-position bottom" in
      assert_true "preview bottom non-tty exits non-zero" (exit_code preview_bottom.status <> 0);
      assert_contains "preview bottom terminal error" ~needle:"cannot start interactive terminal" preview_bottom.stderr;

      let debug = run_debug bin "he" in
      assert_exit "debug search exits zero" 0 debug;
      assert_equal_string "debug search stdout unchanged" search.stdout debug.stdout;
      assert_contains "debug writes to stderr" ~needle:"[ofzf-debug]" debug.stderr;
      assert_not_contains "debug does not log file contents" ~needle:"hello" debug.stderr
