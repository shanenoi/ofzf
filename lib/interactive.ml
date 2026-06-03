type state = {
  query : string;
  context : Search_engine.search_context;
  results : Matcher.match_result list;
  selected : int;
}

let result_rows ~terminal_height = max 1 (terminal_height - 3)

let clamp_selection ~selected ~result_count =
  if result_count <= 0 then 0 else min (result_count - 1) (max 0 selected)

let visible_window ~selected ~terminal_height ~result_count =
  let rows = result_rows ~terminal_height in
  let selected = clamp_selection ~selected ~result_count in
  let start = if selected < rows then 0 else selected - rows + 1 in
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

let nth_opt list index =
  let rec loop current = function
    | [] -> None
    | value :: _ when current = index -> Some value
    | _ :: rest -> loop (current + 1) rest
  in
  if index < 0 then None else loop 0 list

let slice list start stop =
  let rec loop index acc = function
    | [] -> List.rev acc
    | _ :: _ when index >= stop -> List.rev acc
    | value :: rest when index >= start -> loop (index + 1) ((index, value) :: acc) rest
    | _ :: rest -> loop (index + 1) acc rest
  in
  loop 0 [] list

let render_line handle ~selected (index, result) =
  let text = result.Matcher.candidate in
  if index = selected then
    Terminal.write handle ("\027[7m" ^ text ^ "\027[0m\n")
  else Terminal.write handle (text ^ "\n")

let render handle state =
  let terminal_height = Terminal.terminal_height () in
  let result_count = List.length state.results in
  let start, stop =
    visible_window ~selected:state.selected ~terminal_height ~result_count
  in
  Terminal.move_cursor handle ~row:1 ~col:1;
  Terminal.clear_screen handle;
  Terminal.move_cursor handle ~row:1 ~col:1;
  Terminal.write handle (Printf.sprintf "> %s\n" state.query);
  Terminal.write handle
    (Printf.sprintf "%d matches · ↑/↓ move · Enter select · Esc cancel\n" result_count);
  if result_count = 0 then Terminal.write handle "(no matches)\n"
  else List.iter (render_line handle ~selected:state.selected) (slice state.results start stop)

let cleanup handle =
  (try
     Terminal.show_cursor handle;
     Terminal.clear_screen handle;
     Terminal.move_cursor handle ~row:1 ~col:1
   with _ -> ());
  Terminal.restore handle

let run_loop handle candidates =
  let rec loop state =
    render handle state;
    match Terminal.read_key handle with
    | Terminal.Ctrl_c -> (None, 130)
    | Terminal.Escape -> (None, 1)
    | Terminal.Enter -> (nth_opt state.results state.selected, 0)
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