type state = {
  query : string;
  context : Search_engine.search_context;
  results : Matcher.match_result list;
  selected : int;
}

let result_rows ~terminal_height = max 0 (terminal_height - 2)

let clamp_selection ~selected ~result_count =
  if result_count <= 0 then 0 else min (result_count - 1) (max 0 selected)

let visible_window ~selected ~terminal_height ~result_count =
  let rows = result_rows ~terminal_height in
  if result_count <= 0 || rows <= 0 then (0, 0)
  else
    let selected = clamp_selection ~selected ~result_count in
    let max_start = max 0 (result_count - rows) in
    let start = min max_start (if selected < rows then 0 else selected - rows + 1) in
    let stop = min result_count (start + rows) in
    (start, stop)

let apply_key_to_query key ~query =
  match key with
  | Terminal.Backspace ->
      if query = "" then query else String.sub query 0 (String.length query - 1)
  | Terminal.Character char when Char.code char >= 0x20 && Char.code char <> 0x7f ->
      query ^ String.make 1 char
  | _ -> query

let apply_key_to_selection key ~selected ~result_count =
  match key with
  | Terminal.Arrow_up -> clamp_selection ~selected:(selected - 1) ~result_count
  | Terminal.Arrow_down -> clamp_selection ~selected:(selected + 1) ~result_count
  | _ -> clamp_selection ~selected ~result_count

let format_status ~result_count ~selected =
  let selection =
    if result_count <= 0 then "no selection"
    else
      Printf.sprintf "%d/%d selected"
        (clamp_selection ~selected ~result_count + 1)
        result_count
  in
  Printf.sprintf "%d matches · %s · ↑/↓ move · Enter select · Esc cancel"
    result_count selection

let empty_results_message ~query =
  if query = "" then "(no candidates match the empty query)"
  else Printf.sprintf "(no matches for %S)" query

let is_position positions index =
  List.exists (( = ) index) positions

let render_candidate ~selected ~positions ~candidate =
  let buffer = Buffer.create (String.length candidate + (List.length positions * 16)) in
  String.iteri
    (fun index char ->
      if is_position positions index then (
        Buffer.add_string buffer Terminal.highlight;
        Buffer.add_char buffer char;
        Buffer.add_string buffer
          (if selected then Terminal.selected_end_highlight else Terminal.end_highlight))
      else Buffer.add_char buffer char)
    candidate;
  Buffer.contents buffer

let render_result_line ~selected (result : Matcher.match_result) =
  let rendered =
    render_candidate ~selected ~positions:result.positions ~candidate:result.candidate
  in
  if selected then Terminal.inverse ^ rendered ^ Terminal.reset else rendered

let selected_result ~selected results =
  let rec loop current = function
    | [] -> (None, 1)
    | value :: _ when current = selected -> (Some value, 0)
    | _ :: rest -> loop (current + 1) rest
  in
  loop 0 results

let recompute candidates state query =
  let search =
    Search_engine.incremental_search ~context:state.context ~query candidates
  in
  {
    query;
    context = search.context;
    results = search.results;
    selected = clamp_selection ~selected:0 ~result_count:(List.length search.results);
  }

let initial_state candidates =
  let search =
    Search_engine.incremental_search ~context:Search_engine.empty_context
      ~query:"" candidates
  in
  {
    query = "";
    context = search.context;
    results = search.results;
    selected = 0;
  }

let slice list start stop =
  let rec loop index acc = function
    | [] -> List.rev acc
    | _ :: _ when index >= stop -> List.rev acc
    | value :: rest when index >= start -> loop (index + 1) ((index, value) :: acc) rest
    | _ :: rest -> loop (index + 1) acc rest
  in
  loop 0 [] list

let render_lines ~terminal_height ~query ~selected results =
  if terminal_height <= 0 then []
  else
    let result_count = List.length results in
    let selected = clamp_selection ~selected ~result_count in
    let start, stop = visible_window ~selected ~terminal_height ~result_count in
    let body =
      if result_count = 0 then [ empty_results_message ~query ]
      else
        slice results start stop
        |> List.map (fun (index, result) ->
               render_result_line ~selected:(index = selected) result)
    in
    let lines = ("> " ^ query) :: format_status ~result_count ~selected :: body in
    let rec take remaining acc = function
      | _ when remaining <= 0 -> List.rev acc
      | [] -> List.rev acc
      | line :: rest -> take (remaining - 1) (line :: acc) rest
    in
    take terminal_height [] lines

let render_line handle line = Terminal.write handle (line ^ "\n")

let render handle state =
  let terminal_height = Terminal.terminal_height () in
  Terminal.move_cursor handle ~row:1 ~col:1;
  Terminal.clear_screen handle;
  Terminal.move_cursor handle ~row:1 ~col:1;
  render_lines ~terminal_height ~query:state.query ~selected:state.selected
    state.results
  |> List.iter (render_line handle)

let cleanup handle =
  (try
     Terminal.show_cursor handle;
     Terminal.clear_screen handle;
     Terminal.move_cursor handle ~row:1 ~col:1;
     Terminal.leave_alternate_screen handle
   with _ -> ());
  Terminal.restore handle

let run_loop handle candidates =
  let rec loop state =
    render handle state;
    match Terminal.read_key handle with
    | Terminal.Ctrl_c -> (None, 130)
    | Terminal.Escape -> (None, 1)
    | Terminal.Enter -> selected_result ~selected:state.selected state.results
    | (Terminal.Arrow_up | Terminal.Arrow_down) as key ->
        let selected =
          apply_key_to_selection key ~selected:state.selected
            ~result_count:(List.length state.results)
        in
        loop { state with selected }
    | key ->
        let query = apply_key_to_query key ~query:state.query in
        if query = state.query then loop state else loop (recompute candidates state query)
  in
  loop (initial_state candidates)

let run ~candidates =
  if candidates = [] then (
    prerr_endline "ofzf: no candidates on stdin for interactive mode";
    1)
  else
    match Terminal.enter_raw_mode () with
    | Error message ->
        prerr_endline ("ofzf: cannot start interactive terminal: " ^ message);
        1
    | Ok handle -> (
        try
          Terminal.enter_alternate_screen handle;
          Terminal.hide_cursor handle;
          let selected, code = run_loop handle candidates in
          cleanup handle;
          (match selected with
          | Some result -> print_endline result.Matcher.candidate
          | None -> ());
          code
        with exn ->
          cleanup handle;
          prerr_endline ("ofzf: interactive terminal error: " ^ Printexc.to_string exn);
          1)