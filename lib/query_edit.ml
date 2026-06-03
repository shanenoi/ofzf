type t = {
  query : string;
  cursor : int;
}

type action =
  | Insert of char
  | Backspace
  | Delete
  | Clear
  | Delete_previous_word
  | Move_left
  | Move_right
  | Move_start
  | Move_end
  | Ignore

let is_continuation_byte char =
  Char.code char land 0xC0 = 0x80

let is_boundary text index =
  index <= 0 || index >= String.length text || not (is_continuation_byte text.[index])

let rec previous_boundary text index =
  if index <= 0 then 0
  else
    let next = index - 1 in
    if is_boundary text next then next else previous_boundary text next

let rec next_boundary text index =
  let length = String.length text in
  if index >= length then length
  else
    let next = index + 1 in
    if is_boundary text next then next else next_boundary text next

let clamp_cursor query cursor =
  let length = String.length query in
  let cursor = min length (max 0 cursor) in
  if is_boundary query cursor then cursor else previous_boundary query cursor

let make ?cursor query =
  let cursor = match cursor with Some cursor -> cursor | None -> String.length query in
  { query; cursor = clamp_cursor query cursor }

let is_word_separator = function
  | ' ' | '\t' | '\r' | '\n' -> true
  | _ -> false

let delete_previous_word_range query cursor =
  let cursor = clamp_cursor query cursor in
  let rec skip_separators index =
    if index <= 0 then 0
    else
      let previous = previous_boundary query index in
      if previous < index && is_word_separator query.[previous] then skip_separators previous
      else index
  in
  let rec skip_word index =
    if index <= 0 then 0
    else
      let previous = previous_boundary query index in
      if previous < index && is_word_separator query.[previous] then index
      else skip_word previous
  in
  let stop = skip_separators cursor in
  let start = skip_word stop in
  (start, cursor)

let delete_range query start stop =
  String.sub query 0 start ^ String.sub query stop (String.length query - stop)

let insert_char state char =
  let cursor = clamp_cursor state.query state.cursor in
  let inserted = String.make 1 char in
  let query =
    String.sub state.query 0 cursor ^ inserted
    ^ String.sub state.query cursor (String.length state.query - cursor)
  in
  { query; cursor = cursor + String.length inserted }

let apply action state =
  let state = make ~cursor:state.cursor state.query in
  match action with
  | Insert char when Char.code char >= 0x20 && Char.code char <> 0x7f ->
      insert_char state char
  | Insert _ | Ignore -> state
  | Backspace ->
      if state.cursor <= 0 then state
      else
        let start = previous_boundary state.query state.cursor in
        { query = delete_range state.query start state.cursor; cursor = start }
  | Delete ->
      if state.cursor >= String.length state.query then state
      else
        let stop = next_boundary state.query state.cursor in
        { state with query = delete_range state.query state.cursor stop }
  | Clear -> { query = ""; cursor = 0 }
  | Delete_previous_word ->
      let start, stop = delete_previous_word_range state.query state.cursor in
      { query = delete_range state.query start stop; cursor = start }
  | Move_left -> { state with cursor = previous_boundary state.query state.cursor }
  | Move_right -> { state with cursor = next_boundary state.query state.cursor }
  | Move_start -> { state with cursor = 0 }
  | Move_end -> { state with cursor = String.length state.query }

let query state = state.query
let cursor state = state.cursor

let delete_previous_word query =
  (apply Delete_previous_word (make query)).query

let apply_append_action action ~query =
  (apply action (make query)).query
