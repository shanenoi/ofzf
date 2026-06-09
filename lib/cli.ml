type preview_position = Preview_right | Preview_bottom

type mode = Search | Bench | Interactive

type config = {
  query : string;
  limit : int option;
  mode : mode;
  preview : bool;
  preview_command : string option;
  preview_position : preview_position;
  multi : bool;
}

type error =
  | Missing_query
  | Invalid_limit of string
  | Negative_limit of int
  | Invalid_preview_position of string
  | Missing_preview_position
  | Missing_preview_command
  | Invalid_preview_command of string
  | Preview_position_without_preview
  | Preview_conflicts_with_bench
  | Preview_conflicts_with_limit
  | Multi_conflicts_with_bench
  | Multi_conflicts_with_limit

type raw_config = {
  raw_query : string option;
  raw_limit : int option;
  raw_bench : bool;
  raw_preview : bool;
  raw_preview_command : string option;
  raw_preview_position : preview_position option;
  raw_multi : bool;
}

let empty_raw =
  {
    raw_query = None;
    raw_limit = None;
    raw_bench = false;
    raw_preview = false;
    raw_preview_command = None;
    raw_preview_position = None;
    raw_multi = false;
  }

let usage program =
  Printf.sprintf
    "usage: %s [--bench] [--limit N] [--preview] [--preview-command COMMAND] [--preview-position right|bottom] [--multi] [QUERY]"
    program

let parse_limit raw =
  match int_of_string_opt raw with
  | None -> Error (Invalid_limit raw)
  | Some value when value < 0 -> Error (Negative_limit value)
  | Some value -> Ok value

let parse_preview_position = function
  | "right" -> Ok Preview_right
  | "bottom" -> Ok Preview_bottom
  | value -> Error (Invalid_preview_position value)

let contains_whitespace value =
  let rec loop index =
    index < String.length value
    &&
    match value.[index] with
    | ' ' | '\t' | '\n' | '\r' -> true
    | _ -> loop (index + 1)
  in
  loop 0

let parse_preview_command command =
  if command = "" || contains_whitespace command then Error (Invalid_preview_command command)
  else if String.length command >= 2 && String.sub command 0 2 = "--" then
    Error (Invalid_preview_command command)
  else Ok command

let set_query (raw : raw_config) query =
  match raw.raw_query with
  | None -> Ok { raw with raw_query = Some query }
  | Some _ -> Error Missing_query

let parse_raw args =
  let rec loop raw = function
    | [] -> Ok raw
    | "--bench" :: rest -> loop { raw with raw_bench = true } rest
    | "--multi" :: rest -> loop { raw with raw_multi = true } rest
    | "--limit" :: raw_limit :: rest -> (
        match parse_limit raw_limit with
        | Ok limit -> loop { raw with raw_limit = Some limit } rest
        | Error error -> Error error)
    | "--limit" :: [] -> Error (Invalid_limit "")
    | "--preview" :: rest -> loop { raw with raw_preview = true } rest
    | "--preview-command" :: command :: rest -> (
        match parse_preview_command command with
        | Ok command -> loop { raw with raw_preview = true; raw_preview_command = Some command } rest
        | Error error -> Error error)
    | "--preview-command" :: [] -> Error Missing_preview_command
    | "--preview-position" :: raw_position :: rest -> (
        match parse_preview_position raw_position with
        | Ok preview_position -> loop { raw with raw_preview_position = Some preview_position } rest
        | Error error -> Error error)
    | "--preview-position" :: [] -> Error Missing_preview_position
    | query :: rest -> (
        match set_query raw query with
        | Ok raw -> loop raw rest
        | Error error -> Error error)
  in
  loop empty_raw args

let validate (raw : raw_config) =
  match
    ( raw.raw_preview_position,
      raw.raw_preview,
      raw.raw_preview_command,
      raw.raw_multi,
      raw.raw_bench,
      raw.raw_limit,
      raw.raw_query )
  with
  | Some _, false, None, _, _, _, _ -> Error Preview_position_without_preview
  | _, true, _, _, true, _, _ -> Error Preview_conflicts_with_bench
  | _, true, _, _, _, Some _, _ -> Error Preview_conflicts_with_limit
  | _, _, _, true, true, _, _ -> Error Multi_conflicts_with_bench
  | _, _, _, true, _, Some _, _ -> Error Multi_conflicts_with_limit
  | _, _, _, _, true, _, None -> Error Missing_query
  | _, false, None, false, false, Some _, None -> Error Missing_query
  | _ ->
      let preview_position = Option.value raw.raw_preview_position ~default:Preview_right in
      let query = Option.value raw.raw_query ~default:"" in
      let mode =
        if raw.raw_bench then Bench
        else if raw.raw_preview || raw.raw_preview_command <> None || raw.raw_multi || raw.raw_query = None then Interactive
        else Search
      in
      let config : config =
        {
          query;
          limit = raw.raw_limit;
          mode;
          preview = raw.raw_preview || raw.raw_preview_command <> None;
          preview_command = raw.raw_preview_command;
          preview_position;
          multi = raw.raw_multi;
        }
      in
      Ok config

let parse argv =
  match Array.to_list argv with
  | [] -> Error Missing_query
  | _program :: args -> (
      match parse_raw args with
      | Error error -> Error error
      | Ok raw -> validate raw)

let error_message program = function
  | Missing_query -> Printf.sprintf "missing query\n%s" (usage program)
  | Invalid_limit "" -> Printf.sprintf "invalid --limit: expected an integer\n%s" (usage program)
  | Invalid_limit raw ->
      Printf.sprintf "invalid --limit %S: expected a non-negative integer\n%s" raw
        (usage program)
  | Negative_limit value ->
      Printf.sprintf "invalid --limit %d: limit must be non-negative\n%s" value
        (usage program)
  | Invalid_preview_position value ->
      Printf.sprintf "invalid --preview-position %S: expected right or bottom\n%s" value
        (usage program)
  | Missing_preview_position ->
      Printf.sprintf "invalid --preview-position: expected right or bottom\n%s"
        (usage program)
  | Missing_preview_command ->
      Printf.sprintf "invalid --preview-command: expected command\n%s" (usage program)
  | Invalid_preview_command command ->
      Printf.sprintf
        "invalid --preview-command %S: expected a single executable name/path without whitespace and not starting with --\n%s"
        command (usage program)
  | Preview_position_without_preview ->
      Printf.sprintf "invalid --preview-position: requires --preview\n%s" (usage program)
  | Preview_conflicts_with_bench ->
      Printf.sprintf "invalid options: --preview cannot be combined with --bench\n%s"
        (usage program)
  | Preview_conflicts_with_limit ->
      Printf.sprintf "invalid options: --preview cannot be combined with --limit\n%s"
        (usage program)
  | Multi_conflicts_with_bench ->
      Printf.sprintf "invalid options: --multi cannot be combined with --bench\n%s"
        (usage program)
  | Multi_conflicts_with_limit ->
      Printf.sprintf "invalid options: --multi cannot be combined with --limit\n%s"
        (usage program)
