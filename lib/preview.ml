type position = Right | Bottom

type rect = { row : int; col : int; rows : int; cols : int }

type layout = {
  enabled : bool;
  position : position option;
  results : rect;
  preview : rect option;
}

let min_result_rows = 3
let min_preview_rows = 3
let min_result_cols = 20
let min_preview_cols = 20

let parse_position = function
  | "right" -> Some Right
  | "bottom" -> Some Bottom
  | _ -> None

let position_to_string = function Right -> "right" | Bottom -> "bottom"

let full_results terminal_rows terminal_cols =
  { row = 3; col = 1; rows = max 0 (terminal_rows - 2); cols = max 0 terminal_cols }

let disabled terminal_rows terminal_cols =
  { enabled = false; position = None; results = full_results terminal_rows terminal_cols; preview = None }

let compute_layout ~terminal_rows ~terminal_cols ~preview ~position =
  let terminal_rows = max 0 terminal_rows in
  let terminal_cols = max 0 terminal_cols in
  if (not preview) || terminal_rows <= 2 || terminal_cols <= 0 then disabled terminal_rows terminal_cols
  else
    let body_rows = max 0 (terminal_rows - 2) in
    match position with
    | Right ->
        let preview_cols = terminal_cols / 2 in
        let result_cols = terminal_cols - preview_cols - 1 in
        if body_rows < min_result_rows || result_cols < min_result_cols || preview_cols < min_preview_cols then
          disabled terminal_rows terminal_cols
        else
          {
            enabled = true;
            position = Some Right;
            results = { row = 3; col = 1; rows = body_rows; cols = result_cols };
            preview = Some { row = 3; col = result_cols + 2; rows = body_rows; cols = preview_cols };
          }
    | Bottom ->
        let preview_rows = max min_preview_rows (body_rows / 3) in
        let result_rows = body_rows - preview_rows - 1 in
        if result_rows < min_result_rows || preview_rows < min_preview_rows || terminal_cols < min_preview_cols then
          disabled terminal_rows terminal_cols
        else
          {
            enabled = true;
            position = Some Bottom;
            results = { row = 3; col = 1; rows = result_rows; cols = terminal_cols };
            preview = Some { row = 3 + result_rows + 1; col = 1; rows = preview_rows; cols = terminal_cols };
          }

let render_preview_lines ~terminal_width ~selected =
  let clip text = Text_width.clip ~width:(max 0 terminal_width) text in
  match selected with
  | None -> [ clip "preview: no selected result" ]
  | Some candidate ->
      let title = clip "preview: selected candidate" in
      let content = clip candidate in
      [ title; content ]
