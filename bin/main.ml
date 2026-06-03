let print_usage_error program error =
  prerr_endline (Ofzf.Cli.error_message program error)

let scored_item original_index (result : Ofzf.Matcher.match_result) =
  Ofzf.Topk.{ value = result; score = result.score; original_index }

let output_result item = print_endline item.Ofzf.Topk.value.Ofzf.Matcher.candidate

let run_full query =
  let rec loop index matches =
    match input_line stdin with
    | line -> (
        match Ofzf.Matcher.match_candidate ~query ~candidate:line with
        | None -> loop (index + 1) matches
        | Some result -> loop (index + 1) (scored_item index result :: matches))
    | exception End_of_file ->
        matches |> List.sort Ofzf.Topk.compare |> List.iter output_result
  in
  loop 0 []

let run_limited query limit =
  let rec loop index best =
    match input_line stdin with
    | line -> (
        match Ofzf.Matcher.match_candidate ~query ~candidate:line with
        | None -> loop (index + 1) best
        | Some result ->
            loop (index + 1) (Ofzf.Topk.add ~k:limit best (scored_item index result)))
    | exception End_of_file -> List.iter output_result best
  in
  loop 0 []

let () =
  let program = if Array.length Sys.argv = 0 then "ofzf" else Sys.argv.(0) in
  match Ofzf.Cli.parse Sys.argv with
  | Error error ->
      print_usage_error program error;
      exit 2
  | Ok { query; limit = Some 0 } -> ignore query
  | Ok { query; limit = Some limit } -> run_limited query limit
  | Ok { query; limit = None } -> run_full query
