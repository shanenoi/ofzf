type state = {
  query : string;
  context : Search_engine.search_context;
  results : Matcher.match_result list;
  selected : int;
  preview : bool;
  preview_position : Preview.position;
}

let header_rows = 2

let result_rows ~terminal_height = max 0 (terminal_height - header_rows)

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

let clip_plain ~terminal_width text =
  Text_width.clip ~width:terminal_width text

let render_prompt ~cursor_byte ~terminal_width ~query =
  Text_width.prompt_view ~terminal_width ~cursor_byte query

let is_query_word_separator = function
  | ' ' | '\t' | '\r' | '\n' -> true
  | _ -> false

let delete_previous_word query =
  let rec skip_separators index =
    if index <= 0 then 0
    else if is_query_word_separator query.[index - 1] then skip_separators (index - 1)
    else index
  in
  let rec skip_word index =
    if index <= 0 then 0
    else if is_query_word_separator query.[index - 1] then index
    else skip_word (index - 1)
  in
  let stop = skip_separators (String.length query) in
  let start = skip_word stop in
  String.sub query 0 start

let apply_key_to_query key ~query =
  match key with
  | Terminal.Ctrl_u -> ""
  | Terminal.Ctrl_w -> delete_previous_word query
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

let format_status ~preview ~result_count ~selected =
  let selection =
    if result_count <= 0 then "no selection"
    else
      Printf.sprintf "%d/%d selected"
        (clamp_selection ~selected ~result_count + 1)
        result_count
  in
  let preview_text = if preview then " · preview" else "" in
  Printf.sprintf "%d matches · %s%s · ↑/↓ move · Enter select · Esc cancel"
    result_count selection preview_text

let empty_results_message ~query =
  if query = "" then "(no candidates match the empty query)"
  else Printf.sprintf "(no matches for %S)" query

let is_position positions index =
  List.exists (( = ) index) positions

let is_cell_position positions cell =
  List.exists
    (fun position -> position >= cell.Text_width.byte_start && position < cell.byte_end)
    positions

let render_candidate ~selected ~positions ~candidate =
  let buffer = Buffer.create (String.length candidate + (List.length positions * 16)) in
  Text_width.cells candidate
  |> List.iter (fun cell ->
         if is_cell_position positions cell then (
           Buffer.add_string buffer Terminal.highlight;
           Buffer.add_string buffer cell.text;
           Buffer.add_string buffer
             (if selected then Terminal.selected_end_highlight else Terminal.end_highlight))
         else Buffer.add_string buffer cell.text);
  Buffer.contents buffer

let render_candidate_clipped ~terminal_width ~selected ~positions ~candidate =
  if terminal_width <= 0 then ""
  else
    let buffer = Buffer.create (min terminal_width (String.length candidate) + (List.length positions * 16)) in
    let rec loop used = function
      | [] -> ()
      | cell :: rest ->
          let next_used = used + cell.Text_width.width in
          if cell.width = 0 then (
            if is_cell_position positions cell then (
              Buffer.add_string buffer Terminal.highlight;
              Buffer.add_string buffer cell.text;
              Buffer.add_string buffer
                (if selected then Terminal.selected_end_highlight else Terminal.end_highlight))
            else Buffer.add_string buffer cell.text;
            loop used rest)
          else if next_used <= terminal_width then (
            if is_cell_position positions cell then (
              Buffer.add_string buffer Terminal.highlight;
              Buffer.add_string buffer cell.text;
              Buffer.add_string buffer
                (if selected then Terminal.selected_end_highlight else Terminal.end_highlight))
            else Buffer.add_string buffer cell.text;
            loop next_used rest)
          else ()
    in
    loop 0 (Text_width.cells candidate);
    Buffer.contents buffer

let render_result_line ?terminal_width ~selected (result : Matcher.match_result) =
  let rendered =
    match terminal_width with
    | None -> render_candidate ~selected ~positions:result.positions ~candidate:result.candidate
    | Some terminal_width ->
        render_candidate_clipped ~terminal_width ~selected ~positions:result.positions
          ~candidate:result.candidate
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
  let result_count = List.length search.results in
  {
    state with
    query;
    context = search.context;
    results = search.results;
    selected = clamp_selection ~selected:state.selected ~result_count;
  }

let initial_state ?(preview = false) ?(preview_position = Preview.Right) ?(initial_query = "") candidates =
  let search =
    Search_engine.incremental_search ~context:Search_engine.empty_context
      ~query:initial_query candidates
  in
  {
    query = initial_query;
    context = search.context;
    results = search.results;
    selected = 0;
    preview;
    preview_position;
  }

let slice list start stop =
  let rec loop index acc = function
    | [] -> List.rev acc
    | _ :: _ when index >= stop -> List.rev acc
    | value :: rest when index >= start -> loop (index + 1) ((index, value) :: acc) rest
    | _ :: rest -> loop (index + 1) acc rest
  in
  loop 0 [] list

let render_preview_pane ~terminal_width ~selected =
  Preview.render_preview_lines ~terminal_width ~selected

let selected_candidate_text ~selected results =
  match fst (selected_result ~selected results) with
  | None -> None
  | Some result -> Some result.Matcher.candidate

let border_line width =
  if width <= 0 then "" else String.make width '-'

let render_preview_box ~width ~height ~selected =
  if height <= 0 || width <= 0 then []
  else
    let content_width = max 0 (width - 2) in
    let content = render_preview_pane ~terminal_width:content_width ~selected in
    let rec pad line =
      let clipped = Text_width.clip ~width:content_width line in
      let pad_width = max 0 (content_width - Text_width.display_width clipped) in
      "|" ^ clipped ^ String.make pad_width ' ' ^ "|"
    in
    let top = "+" ^ border_line content_width ^ "+" in
    let bottom = top in
    let body_rows = max 0 (height - 2) in
    let rec take_fill remaining acc rows =
      if remaining <= 0 then List.rev acc
      else
        match rows with
        | line :: rest -> take_fill (remaining - 1) (pad line :: acc) rest
        | [] -> take_fill (remaining - 1) (pad "" :: acc) []
    in
    if height = 1 then [ Text_width.clip ~width top ]
    else top :: take_fill body_rows [] content @ [ bottom ]

let render_lines ?terminal_width ?(preview = false) ?(preview_position = Preview.Right) ~terminal_height ~query ~selected results =
  if terminal_height <= 0 then []
  else
    let clip_line line =
      match terminal_width with
      | None -> line
      | Some terminal_width -> clip_plain ~terminal_width line
    in
    let result_count = List.length results in
    let selected = clamp_selection ~selected ~result_count in
    let start, stop = visible_window ~selected ~terminal_height ~result_count in
    let result_body =
      if result_count = 0 then [ clip_line (empty_results_message ~query) ]
      else
        slice results start stop
        |> List.map (fun (index, result) ->
               render_result_line ?terminal_width ~selected:(index = selected) result)
    in
    let body =
      match terminal_width with
      | None -> result_body
      | Some terminal_width ->
          let layout =
            Preview.compute_layout ~terminal_rows:terminal_height
              ~terminal_cols:terminal_width ~preview ~position:preview_position
          in
          if not layout.enabled then result_body
          else
            match layout.preview with
            | None -> result_body
            | Some preview_rect -> (
                match preview_position with
                | Preview.Right ->
                    let result_width = layout.results.Preview.cols in
                    let preview_lines =
                      render_preview_box ~width:preview_rect.cols ~height:preview_rect.rows
                        ~selected:(selected_candidate_text ~selected results)
                    in
                    let result_lines =
                      if result_count = 0 then [ Text_width.clip ~width:result_width (empty_results_message ~query) ]
                      else
                        slice results start stop
                        |> List.map (fun (index, result) ->
                               render_result_line ~terminal_width:result_width
                                 ~selected:(index = selected) result)
                    in
                    let rows = max (List.length result_lines) (List.length preview_lines) in
                    let rec nth_default default index values =
                      match values with
                      | [] -> default
                      | value :: _ when index = 0 -> value
                      | _ :: rest -> nth_default default (index - 1) rest
                    in
                    let rec loop index acc =
                      if index >= rows then List.rev acc
                      else
                        let left = nth_default "" index result_lines in
                        let right = nth_default "" index preview_lines in
                        let left_width = Text_width.display_width left in
                        let left_pad = max 0 (result_width - left_width) in
                        loop (index + 1)
                          ((left ^ String.make left_pad ' ' ^ " " ^ right) :: acc)
                    in
                    loop 0 []
                | Preview.Bottom ->
                    let result_width = layout.results.Preview.cols in
                    let result_lines =
                      if result_count = 0 then [ Text_width.clip ~width:result_width (empty_results_message ~query) ]
                      else
                        slice results start (min stop (start + layout.results.Preview.rows))
                        |> List.map (fun (index, result) ->
                               render_result_line ~terminal_width:result_width
                                 ~selected:(index = selected) result)
                    in
                    let preview_lines =
                      render_preview_box ~width:preview_rect.cols ~height:preview_rect.rows
                        ~selected:(selected_candidate_text ~selected results)
                    in
                    result_lines @ preview_lines)
    in
    let prompt_line =
      match terminal_width with
      | None -> "> " ^ Text_width.sanitize query
      | Some terminal_width ->
          (render_prompt ~cursor_byte:(String.length query) ~terminal_width ~query).Text_width.visible
    in
    let lines =
      prompt_line
      :: clip_line (format_status ~preview ~result_count ~selected)
      :: body
    in
    let rec take remaining acc = function
      | _ when remaining <= 0 -> List.rev acc
      | [] -> List.rev acc
      | line :: rest -> take (remaining - 1) (line :: acc) rest
    in
    take terminal_height [] lines

let render_line handle line = Terminal.write handle (line ^ "\n")

let render handle state =
  let terminal_size = Terminal.terminal_size () in
  let prompt =
    render_prompt ~cursor_byte:(String.length state.query)
      ~terminal_width:terminal_size.cols ~query:state.query
  in
  Terminal.move_cursor handle ~row:1 ~col:1;
  Terminal.clear_screen handle;
  Terminal.move_cursor handle ~row:1 ~col:1;
  render_lines ~terminal_height:terminal_size.rows ~terminal_width:terminal_size.cols
    ~preview:state.preview ~preview_position:state.preview_position
    ~query:state.query ~selected:state.selected state.results
  |> List.iter (render_line handle);
  Terminal.move_cursor handle ~row:1 ~col:(prompt.cursor_col + 1)

let cleanup handle =
  (try
     Terminal.show_cursor handle;
     Terminal.clear_screen handle;
     Terminal.move_cursor handle ~row:1 ~col:1;
     Terminal.leave_alternate_screen handle
   with _ -> ());
  Terminal.restore handle

let run_loop handle ~preview:handle_preview ~preview_position:handle_preview_position ~initial_query:handle_initial_query candidates =
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
  loop (initial_state ~preview:handle_preview ~preview_position:handle_preview_position ~initial_query:handle_initial_query candidates)

let run ?(preview = false) ?(preview_position = Preview.Right) ?(initial_query = "") ~candidates =
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
          let selected, code = run_loop handle ~preview ~preview_position ~initial_query candidates in
          cleanup handle;
          (match selected with
          | Some result -> print_endline result.Matcher.candidate
          | None -> ());
          code
        with exn ->
          cleanup handle;
          prerr_endline ("ofzf: interactive terminal error: " ^ Printexc.to_string exn);
          1)