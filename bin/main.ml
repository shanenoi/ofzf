let input_lines () =
  let rec loop acc =
    match input_line stdin with
    | line -> loop (line :: acc)
    | exception End_of_file -> List.rev acc
  in
  loop []

let query_from_argv () =
  match Array.to_list Sys.argv with
  | _ :: query :: _ -> query
  | _ -> ""

let () =
  input_lines ()
  |> Ofzf.Matcher.rank ~query:(query_from_argv ())
  |> List.iter (fun result -> print_endline result.Ofzf.Matcher.candidate)
