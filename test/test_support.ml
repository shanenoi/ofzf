let assert_true message value = if not value then failwith message

let assert_equal_int message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %d, got %d" message expected actual)

let assert_equal_string message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %S, got %S" message expected actual)

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

let assert_greater message left right =
  if left <= right then
    failwith (Printf.sprintf "%s: expected %d > %d" message left right)

let contains ~needle value =
  let needle_length = String.length needle in
  let value_length = String.length value in
  let rec loop index =
    if needle_length = 0 then true
    else if index + needle_length > value_length then false
    else if String.sub value index needle_length = needle then true
    else loop (index + 1)
  in
  loop 0

let assert_contains message ~needle value =
  if not (contains ~needle value) then
    failwith (Printf.sprintf "%s: expected %S to contain %S" message value needle)

let assert_not_contains message ~needle value =
  if contains ~needle value then
    failwith (Printf.sprintf "%s: expected %S not to contain %S" message value needle)

let starts_with ~prefix value =
  let prefix_length = String.length prefix in
  String.length value >= prefix_length
  && String.sub value 0 prefix_length = prefix

let ends_with ~suffix value =
  let suffix_length = String.length suffix in
  let value_length = String.length value in
  value_length >= suffix_length
  && String.sub value (value_length - suffix_length) suffix_length = suffix

let require_match query candidate =
  match Ofzf.Matcher.match_candidate ~query ~candidate with
  | Some result -> result
  | None -> failwith (Printf.sprintf "expected %S to match %S" candidate query)

let ranked_candidates query candidates =
  Ofzf.Matcher.rank ~query candidates
  |> List.map (fun result -> result.Ofzf.Matcher.candidate)

let ranked_top_candidates query k candidates =
  Ofzf.Matcher.rank_top ~query ~k candidates
  |> List.map (fun result -> result.Ofzf.Matcher.candidate)

let take count values =
  let rec loop remaining acc = function
    | _ when remaining <= 0 -> List.rev acc
    | [] -> List.rev acc
    | value :: rest -> loop (remaining - 1) (value :: acc) rest
  in
  loop count [] values

let write_file path contents =
  let channel = open_out_bin path in
  output_string channel contents;
  close_out channel

let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let with_temp_dir callback =
  let base = Filename.temp_file "ofzf-test" "dir" in
  Sys.remove base;
  Unix.mkdir base 0o700;
  Fun.protect
    ~finally:(fun () ->
      let rec remove_tree path =
        if Sys.is_directory path then (
          Sys.readdir path
          |> Array.iter (fun child -> remove_tree (Filename.concat path child));
          Unix.rmdir path)
        else Sys.remove path
      in
      remove_tree base)
    (fun () -> callback base)

let shell_quote value =
  let buffer = Buffer.create (String.length value + 2) in
  Buffer.add_char buffer '\'';
  String.iter
    (function
      | '\'' -> Buffer.add_string buffer "'\\''"
      | char -> Buffer.add_char buffer char)
    value;
  Buffer.add_char buffer '\'';
  Buffer.contents buffer

type process_result = {
  command : string;
  status : Unix.process_status;
  stdout : string;
  stderr : string;
}

let command_string program args =
  String.concat " " (List.map shell_quote (program :: args))

let merge_environment overrides =
  let override_names = List.map fst overrides in
  let is_overridden entry =
    match String.index_opt entry '=' with
    | None -> false
    | Some index ->
        let name = String.sub entry 0 index in
        List.exists (( = ) name) override_names
  in
  Array.to_list (Unix.environment ())
  |> List.filter (fun entry -> not (is_overridden entry))
  |> fun base ->
  base @ List.map (fun (name, value) -> name ^ "=" ^ value) overrides
  |> Array.of_list

let run_process ?(stdin = "") ?(env = []) program args =
  with_temp_dir (fun dir ->
      let stdin_path = Filename.concat dir "stdin" in
      let stdout_path = Filename.concat dir "stdout" in
      let stderr_path = Filename.concat dir "stderr" in
      write_file stdin_path stdin;
      let stdin_fd = Unix.openfile stdin_path [ Unix.O_RDONLY ] 0 in
      let stdout_fd = Unix.openfile stdout_path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o600 in
      let stderr_fd = Unix.openfile stderr_path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o600 in
      Fun.protect
        ~finally:(fun () ->
          List.iter
            (fun fd -> try Unix.close fd with Unix.Unix_error _ -> ())
            [ stdin_fd; stdout_fd; stderr_fd ])
        (fun () ->
          let argv = Array.of_list (program :: args) in
          let pid = Unix.create_process_env program argv (merge_environment env) stdin_fd stdout_fd stderr_fd in
          let _, status = Unix.waitpid [] pid in
          {
            command = command_string program args;
            status;
            stdout = read_file stdout_path;
            stderr = read_file stderr_path;
          }))

let exit_code = function
  | Unix.WEXITED code -> code
  | Unix.WSIGNALED signal -> 128 + signal
  | Unix.WSTOPPED signal -> 128 + signal

let process_result_details result =
  Printf.sprintf "command: %s\nexit status: %d\nstdout:\n%s\nstderr:\n%s" result.command
    (exit_code result.status) result.stdout result.stderr

let assert_process_exit message expected result =
  if exit_code result.status <> expected then
    failwith
      (Printf.sprintf "%s: expected exit %d, got %d\n%s" message expected
         (exit_code result.status) (process_result_details result))

let assert_process_not_exit message unexpected result =
  if exit_code result.status = unexpected then
    failwith
      (Printf.sprintf "%s: expected exit other than %d\n%s" message unexpected
         (process_result_details result))

let assert_process_stdout message expected result =
  if result.stdout <> expected then
    failwith
      (Printf.sprintf "%s: expected stdout %S, got %S\n%s" message expected
         result.stdout (process_result_details result))

let assert_process_stderr message expected result =
  if result.stderr <> expected then
    failwith
      (Printf.sprintf "%s: expected stderr %S, got %S\n%s" message expected
         result.stderr (process_result_details result))

let assert_process_stdout_contains message ~needle result =
  if not (contains ~needle result.stdout) then
    failwith
      (Printf.sprintf "%s: expected stdout to contain %S\n%s" message needle
         (process_result_details result))

let assert_process_stderr_contains message ~needle result =
  if not (contains ~needle result.stderr) then
    failwith
      (Printf.sprintf "%s: expected stderr to contain %S\n%s" message needle
         (process_result_details result))

let assert_process_stdout_empty message result =
  assert_process_stdout message "" result

let assert_process_stderr_empty message result =
  assert_process_stderr message "" result

let ofzf_binary () =
  match Sys.getenv_opt "OFZF_TEST_BIN" with
  | Some bin when bin <> "" && Sys.file_exists bin -> bin
  | Some bin when bin <> "" ->
      failwith (Printf.sprintf "OFZF_TEST_BIN points to a missing binary: %s" bin)
  | _ ->
      failwith
        "OFZF_TEST_BIN is not set. Run process-level CLI tests through `dune \
         runtest`, which builds bin/main.exe and sets OFZF_TEST_BIN."

let fixture_dir () =
  let candidates =
    [
      "test/fixtures";
      "fixtures";
      Filename.concat ".." "test/fixtures";
      Filename.concat ".." "fixtures";
      Filename.concat (Filename.concat ".." "..") "test/fixtures";
      Filename.concat (Filename.concat ".." "..") "fixtures";
    ]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some path -> path
  | None -> "test/fixtures"

let fixture name = Filename.concat (fixture_dir ()) name

let missing_fixture name = Filename.concat (fixture_dir ()) name
