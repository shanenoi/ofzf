type cell = {
  text : string;
  byte_start : int;
  byte_end : int;
  width : int;
}

type prompt_view = {
  visible : string;
  cursor_col : int;
}

let replacement = "\239\191\189"

let byte s index = Char.code s.[index]
let is_continuation value = value land 0xc0 = 0x80
let in_range value low high = value >= low && value <= high

let invalid index = (0xfffd, index + 1, false)

let decode_one s index =
  let length = String.length s in
  if index >= length then invalid index
  else
    let b0 = byte s index in
    if b0 < 0x80 then (b0, index + 1, true)
    else if in_range b0 0xc2 0xdf then
      if index + 1 < length then
        let b1 = byte s (index + 1) in
        if is_continuation b1 then
          (((b0 land 0x1f) lsl 6) lor (b1 land 0x3f), index + 2, true)
        else invalid index
      else invalid index
    else if b0 = 0xe0 then
      if index + 2 < length then
        let b1 = byte s (index + 1) in
        let b2 = byte s (index + 2) in
        if in_range b1 0xa0 0xbf && is_continuation b2 then
          (((b0 land 0x0f) lsl 12) lor ((b1 land 0x3f) lsl 6) lor (b2 land 0x3f), index + 3, true)
        else invalid index
      else invalid index
    else if in_range b0 0xe1 0xec || in_range b0 0xee 0xef then
      if index + 2 < length then
        let b1 = byte s (index + 1) in
        let b2 = byte s (index + 2) in
        if is_continuation b1 && is_continuation b2 then
          (((b0 land 0x0f) lsl 12) lor ((b1 land 0x3f) lsl 6) lor (b2 land 0x3f), index + 3, true)
        else invalid index
      else invalid index
    else if b0 = 0xed then
      if index + 2 < length then
        let b1 = byte s (index + 1) in
        let b2 = byte s (index + 2) in
        if in_range b1 0x80 0x9f && is_continuation b2 then
          (((b0 land 0x0f) lsl 12) lor ((b1 land 0x3f) lsl 6) lor (b2 land 0x3f), index + 3, true)
        else invalid index
      else invalid index
    else if b0 = 0xf0 then
      if index + 3 < length then
        let b1 = byte s (index + 1) in
        let b2 = byte s (index + 2) in
        let b3 = byte s (index + 3) in
        if in_range b1 0x90 0xbf && is_continuation b2 && is_continuation b3 then
          (((b0 land 0x07) lsl 18) lor ((b1 land 0x3f) lsl 12) lor ((b2 land 0x3f) lsl 6) lor (b3 land 0x3f), index + 4, true)
        else invalid index
      else invalid index
    else if in_range b0 0xf1 0xf3 then
      if index + 3 < length then
        let b1 = byte s (index + 1) in
        let b2 = byte s (index + 2) in
        let b3 = byte s (index + 3) in
        if is_continuation b1 && is_continuation b2 && is_continuation b3 then
          (((b0 land 0x07) lsl 18) lor ((b1 land 0x3f) lsl 12) lor ((b2 land 0x3f) lsl 6) lor (b3 land 0x3f), index + 4, true)
        else invalid index
      else invalid index
    else if b0 = 0xf4 then
      if index + 3 < length then
        let b1 = byte s (index + 1) in
        let b2 = byte s (index + 2) in
        let b3 = byte s (index + 3) in
        if in_range b1 0x80 0x8f && is_continuation b2 && is_continuation b3 then
          (((b0 land 0x07) lsl 18) lor ((b1 land 0x3f) lsl 12) lor ((b2 land 0x3f) lsl 6) lor (b3 land 0x3f), index + 4, true)
        else invalid index
      else invalid index
    else invalid index

let is_combining codepoint =
  in_range codepoint 0x0300 0x036f
  || in_range codepoint 0x1ab0 0x1aff
  || in_range codepoint 0x1dc0 0x1dff
  || in_range codepoint 0x20d0 0x20ff
  || in_range codepoint 0xfe20 0xfe2f

let is_wide codepoint =
  in_range codepoint 0x1100 0x115f
  || codepoint = 0x2329 || codepoint = 0x232a
  || in_range codepoint 0x2e80 0xa4cf
  || in_range codepoint 0xac00 0xd7a3
  || in_range codepoint 0xf900 0xfaff
  || in_range codepoint 0xfe10 0xfe19
  || in_range codepoint 0xfe30 0xfe6f
  || in_range codepoint 0xff00 0xff60
  || in_range codepoint 0xffe0 0xffe6
  || in_range codepoint 0x1f000 0x1faff

let codepoint_width ~tab_width codepoint =
  if codepoint = 0x09 then max 1 tab_width
  else if codepoint < 0x20 || in_range codepoint 0x7f 0x9f then 0
  else if is_combining codepoint then 0
  else if is_wide codepoint then 2
  else 1

let cells ?(tab_width = 4) text =
  let rec loop index acc =
    if index >= String.length text then List.rev acc
    else
      let codepoint, next_index, valid = decode_one text index in
      let bytes = if valid then String.sub text index (next_index - index) else replacement in
      let width = codepoint_width ~tab_width codepoint in
      loop next_index ({ text = bytes; byte_start = index; byte_end = next_index; width } :: acc)
  in
  loop 0 []

let sanitize text =
  cells text |> List.map (fun cell -> cell.text) |> String.concat ""

let display_width ?(tab_width = 4) text =
  cells ~tab_width text |> List.fold_left (fun total cell -> total + cell.width) 0

let display_width_until_byte ?(tab_width = 4) ~byte_index text =
  cells ~tab_width text
  |> List.fold_left
       (fun total cell ->
         if cell.byte_end <= byte_index then total + cell.width else total)
       0

let byte_index_for_display_column ?(tab_width = 4) ~column text =
  let target = max 0 column in
  let rec loop used = function
    | [] -> String.length text
    | cell :: _ when used >= target -> cell.byte_start
    | cell :: _ when cell.width > 0 && used + cell.width > target -> cell.byte_start
    | cell :: rest -> loop (used + cell.width) rest
  in
  loop 0 (cells ~tab_width text)

let clip_cells_to_width ~width cells =
  if width <= 0 then ""
  else
    let rec loop used acc = function
      | [] -> String.concat "" (List.rev acc)
      | cell :: rest ->
          let next_used = used + cell.width in
          if cell.width = 0 then loop used (cell.text :: acc) rest
          else if next_used <= width then loop next_used (cell.text :: acc) rest
          else String.concat "" (List.rev acc)
    in
    loop 0 [] cells

let clip ?(tab_width = 4) ~width text =
  clip_cells_to_width ~width (cells ~tab_width text)

let slice ?(tab_width = 4) ~start_byte ~width text =
  cells ~tab_width text
  |> List.filter (fun cell -> cell.byte_end > start_byte)
  |> clip_cells_to_width ~width

let prompt_view ?(tab_width = 4) ?(prompt = "> ") ~terminal_width ~cursor_byte query =
  let terminal_width = max 0 terminal_width in
  if terminal_width = 0 then { visible = ""; cursor_col = 0 }
  else
    let prompt = clip ~tab_width ~width:terminal_width prompt in
    let prompt_width = display_width ~tab_width prompt in
    let available = max 0 (terminal_width - prompt_width) in
    let query_cells = cells ~tab_width query in
    let cursor_byte = min (String.length query) (max 0 cursor_byte) in
    let rec drop_until_visible before_cursor_width = function
      | [] -> (0, before_cursor_width, query_cells)
      | cell :: rest as all ->
          if before_cursor_width <= available then (cell.byte_start, before_cursor_width, all)
          else if cell.byte_end <= cursor_byte then
            drop_until_visible (before_cursor_width - cell.width) rest
          else (cell.byte_start, before_cursor_width, all)
    in
    let before_cursor_width = display_width_until_byte ~tab_width ~byte_index:cursor_byte query in
    let _start_byte, cursor_visible_width, visible_cells = drop_until_visible before_cursor_width query_cells in
    let visible_query = clip_cells_to_width ~width:available visible_cells in
    let visible = prompt ^ visible_query in
    let unclamped_cursor = prompt_width + cursor_visible_width in
    let cursor_col = min (max 0 (terminal_width - 1)) (max 0 unclamped_cursor) in
    { visible; cursor_col }
