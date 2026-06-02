let fuzzy_match query candidate =
  let query = String.lowercase_ascii query in
  let candidate = String.lowercase_ascii candidate in
  let rec loop qi ci =
    if qi = String.length query then true
    else if ci = String.length candidate then false
    else if query.[qi] = candidate.[ci] then loop (qi + 1) (ci + 1)
    else loop qi (ci + 1)
  in
  loop 0 0

let score query candidate =
  if fuzzy_match query candidate then Some (1000 - String.length candidate) else None

let input_lines () =
  let rec loop acc =
    match input_line stdin with
    | line -> loop (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  loop []

let () =
  let query =
    match Array.to_list Sys.argv with
    | _ :: query :: _ -> query
    | _ -> ""
  in
  input_lines ()
  |> List.filter_map (fun line ->
         match score query line with
         | Some value -> Some (value, line)
         | None -> None)
  |> List.sort (fun (left_score, left_line) (right_score, right_line) ->
         match compare right_score left_score with
         | 0 -> compare left_line right_line
         | by_score -> by_score)
  |> List.iter (fun (_, line) -> print_endline line)
