let header_rows = 2

let result_rows ~terminal_height = max 0 (terminal_height - header_rows)

let visible_window_for_rows ~selected ~visible_rows ~result_count =
  let rows = max 0 visible_rows in
  if result_count <= 0 || rows <= 0 then (0, 0)
  else
    let selected = Selection.clamp ~selected ~result_count in
    let max_start = max 0 (result_count - rows) in
    let start = min max_start (if selected < rows then 0 else selected - rows + 1) in
    let stop = min result_count (start + rows) in
    (start, stop)

let visible_window ~selected ~terminal_height ~result_count =
  visible_window_for_rows ~selected ~visible_rows:(result_rows ~terminal_height) ~result_count

let layout_for_render ~terminal_height ~terminal_width ~preview ~preview_position =
  match terminal_width with
  | None -> Preview.disabled terminal_height 0
  | Some terminal_width ->
      Preview.compute_layout ~terminal_rows:terminal_height ~terminal_cols:terminal_width
        ~preview ~position:preview_position

let result_visible_rows ~terminal_height ~terminal_width ~preview ~preview_position =
  let layout = layout_for_render ~terminal_height ~terminal_width ~preview ~preview_position in
  let open Preview in
  if layout.enabled then layout.results.rows else result_rows ~terminal_height
