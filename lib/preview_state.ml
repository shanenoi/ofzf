type t = {
  selected_candidate : string option;
  content : Preview.content;
  scroll : int;
}

let default = {
  selected_candidate = None;
  content = Preview.no_selection_content;
  scroll = 0;
}

let load_content selected_candidate =
  Preview.content_for_selection ~max_bytes:Preview.max_preview_bytes selected_candidate

let update ?(loader = load_content) previous selected_candidate =
  if previous.selected_candidate = selected_candidate then previous
  else { selected_candidate; content = loader selected_candidate; scroll = 0 }

let clamp_scroll ~visible_rows state =
  let line_count = Preview.content_line_count state.content in
  { state with scroll = Preview.clamp_scroll ~scroll:state.scroll ~line_count ~visible_rows }

let scroll_delta ~visible_rows = function
  | Terminal.Alt_up | Terminal.Ctrl_y -> Some (-1)
  | Terminal.Alt_down | Terminal.Ctrl_e -> Some 1
  | Terminal.Ctrl_b -> Some (-max 1 visible_rows)
  | Terminal.Ctrl_f -> Some (max 1 visible_rows)
  | Terminal.Character _
  | Terminal.Backspace
  | Terminal.Ctrl_u
  | Terminal.Ctrl_w
  | Terminal.Ctrl_c
  | Terminal.Enter
  | Terminal.Escape
  | Terminal.Arrow_up
  | Terminal.Arrow_down
  | Terminal.Page_up
  | Terminal.Page_down
  | Terminal.Unknown _ -> None

let apply_scroll_key ~visible_rows key state =
  match scroll_delta ~visible_rows key with
  | None -> None
  | Some delta ->
      let line_count = Preview.content_line_count state.content in
      let scroll = Preview.scroll_by ~scroll:state.scroll ~delta ~line_count ~visible_rows in
      Some { state with scroll }
