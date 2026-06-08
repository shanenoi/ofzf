let clip_plain ~terminal_width text = Text_width.clip ~width:terminal_width text

let render_prompt ~cursor_byte ~terminal_width ~query =
  Text_width.prompt_view ~terminal_width ~cursor_byte query

let format_status ~multi_selected_count ~preview ~result_count ~selected =
  let selection =
    match multi_selected_count with
    | Some count -> Printf.sprintf "%d selected" count
    | None ->
        if result_count <= 0 then "no selection"
        else
          Printf.sprintf "%d/%d selected"
            (Selection.clamp ~selected ~result_count + 1)
            result_count
  in
  let preview_text = if preview then " · preview" else "" in
  Printf.sprintf "%d matches · %s%s · ↑/↓ move · Enter select · Esc cancel"
    result_count selection preview_text

let empty_results_message ~query =
  if query = "" then "(no candidates match the empty query)"
  else Printf.sprintf "(no matches for %S)" query

let is_cell_position positions (cell : Text_width.cell) =
  List.exists
    (fun position -> position >= cell.byte_start && position < cell.byte_end)
    positions

let render_cell buffer ~selected ~positions (cell : Text_width.cell) =
  if is_cell_position positions cell then (
    Buffer.add_string buffer Terminal.highlight;
    Buffer.add_string buffer cell.text;
    Buffer.add_string buffer
      (if selected then Terminal.selected_end_highlight else Terminal.end_highlight))
  else Buffer.add_string buffer cell.text

let render_candidate ~selected ~positions ~candidate =
  let buffer = Buffer.create (String.length candidate + (List.length positions * 16)) in
  List.iter (render_cell buffer ~selected ~positions) (Text_width.cells candidate);
  Buffer.contents buffer

let render_candidate_clipped ~terminal_width ~selected ~positions ~candidate =
  if terminal_width <= 0 then ""
  else
    let buffer =
      Buffer.create (min terminal_width (String.length candidate) + (List.length positions * 16))
    in
    let rec loop used = function
      | [] -> ()
      | (cell : Text_width.cell) :: rest ->
          let next_used = used + cell.width in
          if cell.width = 0 then (
            render_cell buffer ~selected ~positions cell;
            loop used rest)
          else if next_used <= terminal_width then (
            render_cell buffer ~selected ~positions cell;
            loop next_used rest)
          else ()
    in
    loop 0 (Text_width.cells candidate);
    Buffer.contents buffer

let marker_width = 4

let multi_marker ~marked = if marked then "[x] " else "[ ] "

let render_result_line ?terminal_width ?(multi = false) ?(marked = false) ~selected
    (result : Matcher.match_result) =
  let candidate_width =
    match (terminal_width, multi) with
    | Some terminal_width, true -> Some (max 0 (terminal_width - marker_width))
    | Some terminal_width, false -> Some terminal_width
    | None, _ -> None
  in
  let rendered =
    match candidate_width with
    | None -> render_candidate ~selected ~positions:result.positions ~candidate:result.candidate
    | Some terminal_width ->
        render_candidate_clipped ~terminal_width ~selected ~positions:result.positions
          ~candidate:result.candidate
  in
  let rendered =
    if multi then
      match terminal_width with
      | Some terminal_width when terminal_width < marker_width ->
          Text_width.clip ~width:terminal_width (multi_marker ~marked)
      | _ -> multi_marker ~marked ^ rendered
    else rendered
  in
  if selected then Terminal.inverse ^ rendered ^ Terminal.reset else rendered

let slice list start stop =
  let rec loop index acc = function
    | [] -> List.rev acc
    | _ :: _ when index >= stop -> List.rev acc
    | value :: rest when index >= start -> loop (index + 1) ((index, value) :: acc) rest
    | _ :: rest -> loop (index + 1) acc rest
  in
  loop 0 [] list

let render_preview_pane ~terminal_width ~height ~scroll content =
  Preview.render_content_lines ~terminal_width ~height ~scroll content

let border_line width = if width <= 0 then "" else String.make width '-'

let render_preview_box ~width ~height ~scroll content =
  if height <= 0 || width <= 0 then []
  else
    let content_width = max 0 (width - 2) in
    let content =
      render_preview_pane ~terminal_width:content_width ~height:(max 0 (height - 2))
        ~scroll content
    in
    let pad line =
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

let nth_default default index values =
  let rec loop current = function
    | [] -> default
    | value :: _ when current = index -> value
    | _ :: rest -> loop (current + 1) rest
  in
  loop 0 values

let render_result_lines ~result_width ~query ~selected ~start ~stop ~marked_candidate_ids results =
  let result_count = List.length results in
  if result_count = 0 then [ Text_width.clip ~width:result_width (empty_results_message ~query) ]
  else
    slice results start stop
    |> List.map (fun (index, result) ->
           render_result_line ~terminal_width:result_width
             ~multi:(marked_candidate_ids <> None)
             ~marked:(
               match marked_candidate_ids with
               | None -> false
               | Some marked_candidate_ids ->
                   Selection.candidate_marked ~marked_candidate_ids
                     ~candidate_id:result.Matcher.original_index)
             ~selected:(index = selected) result)

let render_lines ?terminal_width ?cursor_byte ?(preview = false)
    ?(preview_position = Preview.Right) ?(preview_content = Preview.no_selection_content)
    ?(preview_scroll = 0) ?marked_candidate_ids ~terminal_height
    ~query ~selected results =
  if terminal_height <= 0 then []
  else
    let result_count = List.length results in
    let selected = Selection.clamp ~selected ~result_count in
    let layout =
      Viewport.layout_for_render ~terminal_height ~terminal_width ~preview ~preview_position
    in
    let visible_rows =
      if layout.Preview.enabled then layout.results.Preview.rows
      else Viewport.result_rows ~terminal_height
    in
    let start, stop =
      Viewport.visible_window_for_rows ~selected ~visible_rows ~result_count
    in
    let clip_line line =
      match terminal_width with
      | None -> line
      | Some terminal_width -> clip_plain ~terminal_width line
    in
    let result_body =
      if result_count = 0 then [ clip_line (empty_results_message ~query) ]
      else
        slice results start stop
        |> List.map (fun (index, result) ->
               render_result_line ?terminal_width ~multi:(marked_candidate_ids <> None)
                 ~marked:(
                   match marked_candidate_ids with
                   | None -> false
                   | Some marked_candidate_ids ->
                       Selection.candidate_marked ~marked_candidate_ids
                         ~candidate_id:result.Matcher.original_index)
                 ~selected:(index = selected) result)
    in
    let body =
      match (terminal_width, layout.Preview.enabled, layout.preview) with
      | Some _terminal_width, true, Some preview_rect -> (
          match preview_position with
          | Preview.Right ->
              let result_width = layout.results.Preview.cols in
              let preview_lines =
                render_preview_box ~width:preview_rect.Preview.cols
                  ~height:preview_rect.rows ~scroll:preview_scroll preview_content
              in
              let result_lines =
                render_result_lines ~result_width ~query ~selected ~start ~stop
                  ~marked_candidate_ids results
              in
              let rows = max (List.length result_lines) (List.length preview_lines) in
              let rec loop index acc =
                if index >= rows then List.rev acc
                else
                  let left = nth_default "" index result_lines in
                  let right = nth_default "" index preview_lines in
                  let left_width = Text_width.display_width_ansi left in
                  let left_pad = max 0 (result_width - left_width) in
                  loop (index + 1) ((left ^ String.make left_pad ' ' ^ " " ^ right) :: acc)
              in
              loop 0 []
          | Preview.Bottom ->
              let result_width = layout.results.Preview.cols in
              let result_lines =
                render_result_lines ~result_width ~query ~selected ~start ~stop
                  ~marked_candidate_ids results
              in
              let preview_lines =
                render_preview_box ~width:preview_rect.Preview.cols
                  ~height:preview_rect.rows ~scroll:preview_scroll preview_content
              in
              result_lines @ preview_lines)
      | _ -> result_body
    in
    let prompt_line =
      match terminal_width with
      | None -> "> " ^ Text_width.sanitize query
      | Some terminal_width ->
          let cursor_byte = Option.value cursor_byte ~default:(String.length query) in
          (render_prompt ~cursor_byte ~terminal_width ~query).Text_width.visible
    in
    let lines =
      prompt_line
      :: clip_line
           (format_status
              ~multi_selected_count:(Option.map List.length marked_candidate_ids)
              ~preview ~result_count ~selected)
      :: body
    in
    let rec take remaining acc = function
      | _ when remaining <= 0 -> List.rev acc
      | [] -> List.rev acc
      | line :: rest -> take (remaining - 1) (line :: acc) rest
    in
    take terminal_height [] lines
