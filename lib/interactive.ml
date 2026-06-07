type preview_state = Preview_state.t = {
  selected_candidate : string option;
  content : Preview.content;
  scroll : int;
}

type state = {
  query : string;
  context : Search_engine.search_context;
  results : Matcher.match_result list;
  selected : int;
  preview : bool;
  preview_position : Preview.position;
  preview_state : preview_state;
}

let result_rows = Viewport.result_rows
let clamp_selection = Selection.clamp
let visible_window_for_rows = Viewport.visible_window_for_rows
let visible_window = Viewport.visible_window
let clip_plain = Render.clip_plain
let render_prompt = Render.render_prompt
let delete_previous_word = Query_edit.delete_previous_word
let format_status = Render.format_status
let empty_results_message = Render.empty_results_message
let render_candidate = Render.render_candidate
let render_candidate_clipped = Render.render_candidate_clipped
let render_result_line = Render.render_result_line
let render_preview_pane = Render.render_preview_pane
let render_lines = Render.render_lines
let selected_result = Selection.selected_result
let default_preview_state = Preview_state.default
let update_preview_state = Preview_state.update
let clamp_preview_state_scroll = Preview_state.clamp_scroll

let query_action_of_key = function
  | Terminal.Ctrl_u -> Query_edit.Clear
  | Terminal.Ctrl_w -> Query_edit.Delete_previous_word
  | Terminal.Backspace -> Query_edit.Backspace
  | Terminal.Character char -> Query_edit.Insert char
  | _ -> Query_edit.Ignore

let apply_key_to_query key ~query =
  Query_edit.apply_append_action (query_action_of_key key) ~query

let selection_action_of_key = function
  | Terminal.Arrow_up -> Selection.Move_up
  | Terminal.Arrow_down -> Selection.Move_down
  | Terminal.Page_up -> Selection.Page_up
  | Terminal.Page_down -> Selection.Page_down
  | _ -> Selection.Stay

let apply_key_to_selection ?(page_size = 10) key ~selected ~result_count =
  Selection.apply_action ~page_size (selection_action_of_key key) ~selected ~result_count

let preview_scroll_delta = Preview_state.scroll_delta

let selected_candidate_text ~selected results =
  Selection.selected_candidate_text ~selected results

let sync_preview_state ?loader state =
  if not state.preview then { state with preview_state = default_preview_state }
  else
    let selected_candidate = selected_candidate_text ~selected:state.selected state.results in
    let preview_state = update_preview_state ?loader state.preview_state selected_candidate in
    { state with preview_state }

let recompute candidates state query =
  let previous_candidate = selected_candidate_text ~selected:state.selected state.results in
  let search = Search_engine.incremental_search ~context:state.context ~query candidates in
  let selected =
    Selection.preserve_selected_candidate ~previous_candidate
      ~fallback_selected:state.selected search.results
  in
  {
    state with
    query;
    context = search.context;
    results = search.results;
    selected;
  }
  |> sync_preview_state

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
    preview_state = default_preview_state;
  }
  |> sync_preview_state

let render_line handle line = Terminal.write handle (line ^ "\n")

let render handle terminal_size state =
  let prompt =
    render_prompt ~cursor_byte:(String.length state.query)
      ~terminal_width:terminal_size.Terminal.cols ~query:state.query
  in
  Terminal.move_cursor handle ~row:1 ~col:1;
  Terminal.clear_screen handle;
  Terminal.move_cursor handle ~row:1 ~col:1;
  render_lines ~terminal_height:terminal_size.rows ~terminal_width:terminal_size.cols
    ~preview:state.preview ~preview_position:state.preview_position
    ~preview_content:state.preview_state.content ~preview_scroll:state.preview_state.scroll
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

let preview_visible_rows ~terminal_height ~terminal_width ~preview ~preview_position =
  let layout =
    Preview.compute_layout ~terminal_rows:terminal_height ~terminal_cols:terminal_width
      ~preview ~position:preview_position
  in
  match layout.preview with
  | None -> 0
  | Some rect -> max 0 (rect.Preview.rows - 3)

let clamp_state_preview_scroll ~visible_rows state =
  { state with preview_state = clamp_preview_state_scroll ~visible_rows state.preview_state }

let apply_preview_scroll_key ~visible_rows key state =
  match Preview_state.apply_scroll_key ~visible_rows key state.preview_state with
  | None -> None
  | Some preview_state -> Some { state with preview_state }

let update_selection selected state =
  { state with selected } |> sync_preview_state

let page_size_for_selection ~terminal_height ~terminal_width state =
  max 1
    (Viewport.result_visible_rows ~terminal_height ~terminal_width:(Some terminal_width)
       ~preview:state.preview ~preview_position:state.preview_position)

let is_selection_key = function
  | Terminal.Arrow_up | Terminal.Arrow_down | Terminal.Page_up | Terminal.Page_down -> true
  | _ -> false

let run_loop handle ~preview:handle_preview ~preview_position:handle_preview_position
    ~initial_query:handle_initial_query candidates =
  let rec loop state =
    let size = Terminal.terminal_size ~handle () in
    Debug.logf "terminal_size rows=%d cols=%d preview=%b layout=%s"
      size.Terminal.rows size.Terminal.cols state.preview
      (Preview.position_to_string state.preview_position);
    render handle size state;
    let visible_preview_rows =
      preview_visible_rows ~terminal_height:size.rows ~terminal_width:size.cols
        ~preview:state.preview ~preview_position:state.preview_position
    in
    match Terminal.read_key handle with
    | Terminal.Ctrl_c -> (None, 130)
    | Terminal.Escape -> (None, 1)
    | Terminal.Enter -> selected_result ~selected:state.selected state.results
    | Terminal.Resize -> loop (clamp_state_preview_scroll ~visible_rows:visible_preview_rows state)
    | key when state.preview -> (
        match apply_preview_scroll_key ~visible_rows:visible_preview_rows key state with
        | Some state -> loop state
        | None ->
            if is_selection_key key then
              let page_size =
                page_size_for_selection ~terminal_height:size.rows ~terminal_width:size.cols state
              in
              let selected =
                apply_key_to_selection ~page_size key ~selected:state.selected
                  ~result_count:(List.length state.results)
              in
              let state =
                if selected = state.selected then
                  clamp_state_preview_scroll ~visible_rows:visible_preview_rows state
                else update_selection selected state
              in
              loop state
            else
              let query = apply_key_to_query key ~query:state.query in
              if query = state.query then loop state else loop (recompute candidates state query))
    | key when is_selection_key key ->
        let page_size = page_size_for_selection ~terminal_height:size.rows ~terminal_width:size.cols state in
        let selected =
          apply_key_to_selection ~page_size key ~selected:state.selected
            ~result_count:(List.length state.results)
        in
        loop { state with selected }
    | key ->
        let query = apply_key_to_query key ~query:state.query in
        if query = state.query then loop state else loop (recompute candidates state query)
  in
  loop
    (initial_state ~preview:handle_preview ~preview_position:handle_preview_position
       ~initial_query:handle_initial_query candidates)

let run ~preview ~preview_position ~initial_query ~candidates =
  if candidates = [] then (
    Debug.log "interactive start failed: empty stdin";
    prerr_endline "ofzf: no candidates on stdin for interactive mode";
    1)
  else
    match Terminal.enter_raw_mode () with
    | Error message ->
        Debug.logf "interactive terminal setup failed: %s" message;
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
