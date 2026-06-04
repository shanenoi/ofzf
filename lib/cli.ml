type preview_position = Preview_right | Preview_bottom

type mode = Search | Bench | Interactive

type config = {
  query : string;
  limit : int option;
  mode : mode;
  preview : bool;
  preview_position : preview_position;
}

type error =
  | Missing_query
  | Invalid_limit of string
  | Negative_limit of int
  | Invalid_preview_position of string
  | Missing_preview_position
  | Preview_position_without_preview
  | Preview_conflicts_with_bench
  | Preview_conflicts_with_limit

type raw_config = {
  raw_query : string option;
  raw_limit : int option;
  raw_bench : bool;
  raw_preview : bool;
  raw_preview_position : preview_position option;
}

let empty_raw =
  { raw_query = None; raw_limit = None; raw_bench = false; raw_preview = false; raw_preview_position = None }

let usage program =
  Printf.sprintf
    "usage: %s [--bench] [--limit N] [--preview] [--preview-position right|bottom] [QUERY]"
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

let set_query (raw : raw_config) query =
  match raw.raw_query with
  | None -> Ok { raw with raw_query = Some query }
  | Some _ -> Error Missing_query

let parse_raw args =
  let rec loop raw = function
    | [] -> Ok raw
    | "--bench" :: rest -> loop { raw with raw_bench = true } rest
    | "--limit" :: raw_limit :: rest -> (
        match parse_limit raw_limit with
        | Ok limit -> loop { raw with raw_limit = Some limit } rest
        | Error error -> Error error)
    | "--limit" :: [] -> Error (Invalid_limit "")
    | "--preview" :: rest -> loop { raw with raw_preview = true } rest
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
  match (raw.raw_preview_position, raw.raw_preview, raw.raw_bench, raw.raw_limit, raw.raw_query) with
  | Some _, false, _, _, _ -> Error Preview_position_without_preview
  | _, true, true, _, _ -> Error Preview_conflicts_with_bench
  | _, true, _, Some _, _ -> Error Preview_conflicts_with_limit
  | _, _, true, _, None -> Error Missing_query
  | _, false, false, Some _, None -> Error Missing_query
  | _ ->
      let preview_position = Option.value raw.raw_preview_position ~default:Preview_right in
      let query = Option.value raw.raw_query ~default:"" in
      let mode =
        if raw.raw_bench then Bench
        else if raw.raw_preview || raw.raw_query = None then Interactive
        else Search
      in
      let config : config =
        { query; limit = raw.raw_limit; mode; preview = raw.raw_preview; preview_position }
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
  | Preview_position_without_preview ->
      Printf.sprintf "invalid --preview-position: requires --preview\n%s" (usage program)
  | Preview_conflicts_with_bench ->
      Printf.sprintf "invalid options: --preview cannot be combined with --bench\n%s"
        (usage program)
  | Preview_conflicts_with_limit ->
      Printf.sprintf "invalid options: --preview cannot be combined with --limit\n%s"
        (usage program)
