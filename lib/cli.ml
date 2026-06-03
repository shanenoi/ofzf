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

let usage program =
  Printf.sprintf "usage: %s [--bench] [--limit N] [--preview] [--preview-position right|bottom] [QUERY]" program

let parse_limit raw =
  match int_of_string_opt raw with
  | None -> Error (Invalid_limit raw)
  | Some value when value < 0 -> Error (Negative_limit value)
  | Some value -> Ok value

let parse argv =
  let rec loop mode limit preview preview_position = function
    | [] -> (
        match (mode, limit) with
        | Search, None | Interactive, None ->
            Ok { query = ""; limit = None; mode = Interactive; preview; preview_position }
        | _ -> Error Missing_query)
    | "--bench" :: rest -> loop Bench limit preview preview_position rest
    | "--limit" :: raw_limit :: rest -> (
        match parse_limit raw_limit with
        | Ok limit -> loop mode (Some limit) preview preview_position rest
        | Error error -> Error error)
    | "--limit" :: [] -> Error (Invalid_limit "")
    | "--preview" :: rest -> loop Interactive limit true preview_position rest
    | "--preview-position" :: raw :: rest -> (
        match raw with
        | "right" -> loop Interactive limit preview Preview_right rest
        | "bottom" -> loop Interactive limit preview Preview_bottom rest
        | value -> Error (Invalid_preview_position value))
    | "--preview-position" :: [] -> Error Missing_preview_position
    | [ query ] -> Ok { query; limit; mode; preview; preview_position }
    | _ -> Error Missing_query
  in
  match Array.to_list argv with
  | [] -> Error Missing_query
  | _program :: args -> loop Search None false Preview_right args

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
