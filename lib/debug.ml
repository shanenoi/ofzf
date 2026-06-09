let enabled () =
  match Sys.getenv_opt "OFZF_DEBUG" with
  | None | Some "" | Some "0" | Some "false" | Some "FALSE" -> false
  | Some _ -> true

let log message =
  if enabled () then prerr_endline ("[ofzf-debug] " ^ message)

let logf format = Printf.ksprintf log format

let preview_kind_to_string = function
  | Preview.No_selection -> "no-selection"
  | Preview.Candidate_text -> "candidate-text"
  | Preview.Regular_file -> "regular-file"
  | Preview.Directory -> "directory"
  | Preview.Missing_path -> "missing-path"
  | Preview.Unreadable_path -> "unreadable-path"
  | Preview.Binary_file -> "binary-file"
  | Preview.Command_output -> "command-output"
  | Preview.Command_error -> "command-error"