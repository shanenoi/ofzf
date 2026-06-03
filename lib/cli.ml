type config = { query : string; limit : int option }

type error = Missing_query | Invalid_limit of string | Negative_limit of int

let usage program = Printf.sprintf "usage: %s [--limit N] QUERY" program

let parse_limit raw =
  match int_of_string_opt raw with
  | None -> Error (Invalid_limit raw)
  | Some value when value < 0 -> Error (Negative_limit value)
  | Some value -> Ok value

let parse argv =
  match Array.to_list argv with
  | [ _program; query ] -> Ok { query; limit = None }
  | [ _program; "--limit"; raw_limit; query ] -> (
      match parse_limit raw_limit with
      | Ok limit -> Ok { query; limit = Some limit }
      | Error error -> Error error)
  | [ _program; "--limit"; raw_limit ] -> Error (Invalid_limit raw_limit)
  | [ _program ] -> Error Missing_query
  | _ -> Error Missing_query

let error_message program = function
  | Missing_query -> Printf.sprintf "missing query\n%s" (usage program)
  | Invalid_limit "" -> Printf.sprintf "invalid --limit: expected an integer\n%s" (usage program)
  | Invalid_limit raw ->
      Printf.sprintf "invalid --limit %S: expected a non-negative integer\n%s" raw
        (usage program)
  | Negative_limit value ->
      Printf.sprintf "invalid --limit %d: limit must be non-negative\n%s" value
        (usage program)
