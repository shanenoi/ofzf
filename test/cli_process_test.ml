open Test_support

let input = "hello\nhelp\nworld\nsomewhere\n"
let pipe_input command = "printf " ^ shell_quote input ^ " | " ^ command
let quote_bin bin = shell_quote bin
let run_ofzf bin args = run_shell (pipe_input (quote_bin bin ^ " " ^ args))
let run_debug bin args = run_shell (pipe_input ("OFZF_DEBUG=1 " ^ quote_bin bin ^ " " ^ args))

let assert_error message result ~needle =
  assert_process_not_exit (message ^ " exits non-zero") 0 result;
  assert_process_stdout_empty (message ^ " keeps stdout empty") result;
  assert_process_stderr_contains (message ^ " stderr") ~needle result

let assert_bench_output result =
  assert_process_exit "bench exits zero" 0 result;
  assert_process_stderr_empty "bench keeps stderr empty" result;
  List.iter
    (fun key -> assert_process_stdout_contains ("bench output has " ^ key) ~needle:key result)
    [
      "query=he";
      "candidate_count=4";
      "matched_count=3";
      "matching_time_seconds=";
      "ranking_time_seconds=";
      "cache_hits=";
      "cache_misses=";
      "incremental_reuse=";
      "incremental_scanned=";
      "candidate_reduction_ratio=";
    ]

let () =
  let bin = ofzf_binary () in
  let search = run_ofzf bin "he" in
  assert_process_exit "ofzf query exits zero" 0 search;
  assert_process_stdout "ofzf query stdout" "help\nhello\nsomewhere\n" search;
  assert_process_stderr_empty "search keeps stderr empty by default" search;

  let limited = run_ofzf bin "--limit 1 he" in
  assert_process_exit "ofzf limit exits zero" 0 limited;
  assert_process_stdout "ofzf limit stdout" "help\n" limited;
  assert_process_stderr_empty "limit keeps stderr empty" limited;

  let zero_limit = run_ofzf bin "--limit 0 he" in
  assert_process_exit "ofzf limit zero exits zero" 0 zero_limit;
  assert_process_stdout_empty "limit zero prints no stdout" zero_limit;
  assert_process_stderr_empty "limit zero keeps stderr empty" zero_limit;

  assert_bench_output (run_ofzf bin "--bench he");

  let bench_limit = run_ofzf bin "--bench --limit 1 he" in
  assert_process_exit "ofzf bench limit exits zero" 0 bench_limit;
  assert_process_stderr_empty "bench limit keeps stderr empty" bench_limit;
  assert_process_stdout_contains "bench limit output includes query" ~needle:"query=he" bench_limit;

  assert_error "bench missing query" (run_ofzf bin "--bench") ~needle:"missing query";
  assert_error "limit missing query" (run_ofzf bin "--limit 2") ~needle:"missing query";
  assert_error "invalid limit" (run_ofzf bin "--limit nope he") ~needle:"invalid --limit";
  assert_error "negative limit" (run_ofzf bin "--limit -1 he") ~needle:"limit must be non-negative";
  assert_error "invalid preview position" (run_ofzf bin "--preview --preview-position side he")
    ~needle:"invalid --preview-position";
  assert_error "preview-position without preview" (run_ofzf bin "--preview-position right he")
    ~needle:"requires --preview";

  let bench_preview = run_ofzf bin "--bench --preview he" in
  let preview_bench = run_ofzf bin "--preview --bench he" in
  assert_error "bench preview" bench_preview ~needle:"cannot be combined with --bench";
  assert_error "preview bench" preview_bench ~needle:"cannot be combined with --bench";
  assert_process_stderr "bench preview order-independent stderr" bench_preview.stderr preview_bench;

  assert_error "preview limit" (run_ofzf bin "--preview --limit 1 he")
    ~needle:"cannot be combined with --limit";

  assert_error "multi bench" (run_ofzf bin "--multi --bench he")
    ~needle:"cannot be combined with --bench";

  assert_error "multi limit" (run_ofzf bin "--multi --limit 1 he")
    ~needle:"cannot be combined with --limit";

  let multi_initial_query = run_ofzf bin "--multi he" in
  assert_error "multi initial query non-tty" multi_initial_query
    ~needle:"cannot start interactive terminal";

  let preview_right = run_ofzf bin "--preview --preview-position right he" in
  assert_error "preview right non-tty" preview_right ~needle:"cannot start interactive terminal";

  let preview_bottom = run_ofzf bin "--preview --preview-position bottom he" in
  assert_error "preview bottom non-tty" preview_bottom ~needle:"cannot start interactive terminal";

  let debug = run_debug bin "he" in
  assert_process_exit "debug search exits zero" 0 debug;
  assert_process_stdout "debug search stdout unchanged" search.stdout debug;
  assert_process_stderr_contains "debug writes to stderr" ~needle:"[ofzf-debug]" debug;
  assert_not_contains "debug does not log file contents" ~needle:"hello" debug.stderr
