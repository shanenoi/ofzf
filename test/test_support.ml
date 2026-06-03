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
  status : Unix.process_status;
  stdout : string;
  stderr : string;
}

let run_shell command =
  with_temp_dir (fun dir ->
      let stdout_path = Filename.concat dir "stdout" in
      let stderr_path = Filename.concat dir "stderr" in
      let status = Sys.command (command ^ " > " ^ shell_quote stdout_path ^ " 2> " ^ shell_quote stderr_path) in
      let status = if status = 0 then Unix.WEXITED 0 else Unix.WEXITED status in
      { status; stdout = read_file stdout_path; stderr = read_file stderr_path })

let exit_code = function
  | Unix.WEXITED code -> code
  | Unix.WSIGNALED signal -> 128 + signal
  | Unix.WSTOPPED signal -> 128 + signal

let ofzf_binary () = Sys.getenv_opt "OFZF_TEST_BIN"