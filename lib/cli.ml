type mode = Search | Bench

type config = {
  query : string;
  limit : int option;
  mode : mode;
}

type error = Missing_query | Invalid_limit of string | Negative_limit of int

let usage program = Printf.sprintf "usage: %s [--bench] [--limit N] QUERY" program

let parse_limit raw =
  match int_of_string_opt raw with
  | None -> Error (Invalid_limit raw)
  | Some value when value < 0 -> Error (Negative_limit value)
  | Some value -> Ok value

let parse argv =
  let rec loop mode limit = function
    | [] -> Error Missing_query
    | "--bench" :: rest -> loop Bench limit rest
    | "--limit" :: raw_limit :: rest -> (
        match parse_limit raw_limit with
        | Ok limit -> loop mode (Some limit) rest
        | Error error -> Error error)
    | "--limit" :: [] -> Error (Invalid_limit "")
    | [ query ] -> Ok { query; limit; mode }
    | _ -> Error Missing_query
  in
  match Array.to_list argv with
  | [] -> Error Missing_query
  | _program :: args -> loop Search None args

let error_message program = function
  | Missing_query -> Printf.sprintf "missing query\n%s" (usage program)
  | Invalid_limit "" -> Printf.sprintf "invalid --limit: expected an integer\n%s" (usage program)
  | Invalid_limit raw ->
      Printf.sprintf "invalid --limit %S: expected a non-negative integer\n%s" raw
        (usage program)
  | Negative_limit value ->
      Printf.sprintf "invalid --limit %d: limit must be non-negative\n%s" value
        (usage program)
