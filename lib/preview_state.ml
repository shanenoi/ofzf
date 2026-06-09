type t = {
  selected_candidate : string option;
  source : Preview.source;
  content : Preview.content;
  scroll : int;
}

let default = {
  selected_candidate = None;
  source = Preview.File_preview;
  content = Preview.no_selection_content;
  scroll = 0;
}

let load_content ~source selected_candidate =
  Preview.content_for_selection ~source ~max_bytes:Preview.max_preview_bytes selected_candidate

let update ?(source = Preview.File_preview) ?(loader = load_content) previous selected_candidate =
  if previous.selected_candidate = selected_candidate && previous.source = source then previous
  else
    let content = loader ~source selected_candidate in
    Debug.logf "preview reload selected=%b source=%s kind=%s line_count=%d"
      (Option.is_some selected_candidate)
      (Preview.source_to_string source)
      (Debug.preview_kind_to_string content.Preview.kind)
      (Preview.content_line_count content);
    { selected_candidate; source; content; scroll = 0 }

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
  | Terminal.Delete
  | Terminal.Ctrl_a
  | Terminal.Ctrl_u
  | Terminal.Ctrl_w
  | Terminal.Ctrl_c
  | Terminal.Enter
  | Terminal.Escape
  | Terminal.Arrow_left
  | Terminal.Arrow_right
  | Terminal.Arrow_up
  | Terminal.Arrow_down
  | Terminal.Home
  | Terminal.End
  | Terminal.Page_up
  | Terminal.Page_down
  | Terminal.Resize
  | Terminal.Unknown _ -> None

let apply_scroll_key ~visible_rows key state =
  match scroll_delta ~visible_rows key with
  | None -> None
  | Some delta ->
      let line_count = Preview.content_line_count state.content in
      let scroll = Preview.scroll_by ~scroll:state.scroll ~delta ~line_count ~visible_rows in
      Some { state with scroll }
