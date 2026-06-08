let assert_true message value = if not value then failwith message
let assert_equal_int message expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %d but got %d" message expected actual)

let contains ~needle value =
  let n = String.length needle and l = String.length value in
  let rec loop i =
    if n = 0 then true
    else if i + n > l then false
    else if String.sub value i n = needle then true
    else loop (i + 1)
  in
  loop 0

let result ?(original_index = 0) candidate positions =
  Ofzf.Matcher.{ candidate; original_index; positions; score = 0 }

let assert_lines_fit ~message ~terminal_height ~terminal_width lines =
  assert_true (message ^ " height") (List.length lines <= max 0 terminal_height);
  List.iter
    (fun line ->
      assert_true (message ^ " width")
        (Ofzf.Text_width.display_width_ansi line <= max 0 terminal_width))
    lines

let () =
  let highlighted = Ofzf.Render.render_candidate ~selected:false ~positions:[ 0; 1 ] ~candidate:"matcher" in
  assert_true "highlight contains ansi" (contains ~needle:Ofzf.Terminal.highlight highlighted);
  let selected = Ofzf.Render.render_result_line ~terminal_width:7 ~selected:true (result "matcher" [ 0 ]) in
  assert_true "selected contains inverse" (contains ~needle:Ofzf.Terminal.inverse selected);
  assert_true "ansi ignored for width"
    (Ofzf.Text_width.display_width_ansi selected <= 7);
  let marked =
    Ofzf.Render.render_result_line ~terminal_width:12 ~multi:true ~marked:true ~selected:false
      (result "matcher" [ 0 ])
  in
  assert_true "multi marked row contains marker" (contains ~needle:"[x]" marked);
  let highlighted_marked =
    Ofzf.Render.render_result_line ~terminal_width:12 ~multi:true ~marked:true ~selected:true
      (result "matcher" [ 0 ])
  in
  assert_true "highlighted multi row remains distinct" (contains ~needle:Ofzf.Terminal.inverse highlighted_marked);
  assert_true "highlighted multi row includes selected marker" (contains ~needle:"[x]" highlighted_marked);
  assert_true "multi row width bounded"
    (Ofzf.Text_width.display_width_ansi highlighted_marked <= 12);
  let unicode = Ofzf.Render.render_result_line ~terminal_width:3 ~selected:false (result "界abc" [ 0 ]) in
  assert_true "unicode clipped safely" (Ofzf.Text_width.display_width_ansi unicode <= 3);
  let empty_prompt = Ofzf.Render.render_prompt ~cursor_byte:0 ~terminal_width:8 ~query:"" in
  assert_true "empty prompt visible" (contains ~needle:"> " empty_prompt.visible);
  assert_equal_int "empty prompt cursor after prefix" 2 empty_prompt.cursor_col;
  let middle_prompt = Ofzf.Render.render_prompt ~cursor_byte:1 ~terminal_width:10 ~query:"mat" in
  assert_true "middle prompt contains query" (contains ~needle:"mat" middle_prompt.visible);
  assert_equal_int "middle prompt cursor includes prefix" 3 middle_prompt.cursor_col;
  let narrow_prompt = Ofzf.Render.render_prompt ~cursor_byte:1 ~terminal_width:1 ~query:"mat" in
  assert_true "narrow prompt cursor clamped" (narrow_prompt.cursor_col >= 0);
  assert_true "narrow prompt width bounded" (Ofzf.Text_width.display_width narrow_prompt.visible <= 1);
  let content = Ofzf.Preview.content_of_candidate_text "preview line" in
  let right =
    Ofzf.Render.render_lines ~terminal_height:8 ~terminal_width:80 ~preview:true
      ~preview_position:Ofzf.Preview.Right ~preview_content:content ~query:"" ~selected:0
      [ result "matcher" [ 0 ] ]
  in
  assert_true "right preview composition contains preview" (List.exists (contains ~needle:"preview line") right);
  let bottom =
    Ofzf.Render.render_lines ~terminal_height:14 ~terminal_width:80 ~preview:true
      ~preview_position:Ofzf.Preview.Bottom ~preview_content:content ~query:"" ~selected:0
      [ result "matcher" [ 0 ] ]
  in
  assert_true "bottom preview composition contains preview" (List.exists (contains ~needle:"preview line") bottom);
  let empty = Ofzf.Render.render_lines ~terminal_height:4 ~terminal_width:80 ~query:"zz" ~selected:0 [] in
  assert_true "empty result message" (List.exists (contains ~needle:"no matches") empty);
  let multi_status =
    Ofzf.Render.render_lines ~terminal_height:4 ~terminal_width:80 ~query:"m" ~selected:1
      ~marked_candidate_ids:[ 1 ]
      [ result ~original_index:0 "matcher.ml" [ 0 ]; result ~original_index:1 "scoring.ml" [ 0 ] ]
  in
  assert_true "multi status shows selected count" (List.exists (contains ~needle:"1 selected") multi_status);
  assert_true "multi render marks selected row" (List.exists (contains ~needle:"[x]") multi_status);
  assert_true "multi render marks unselected rows too" (List.exists (contains ~needle:"[ ]") multi_status);
  let zero =
    Ofzf.Render.render_lines ~terminal_height:0 ~terminal_width:80 ~query:"m" ~selected:0
      [ result "matcher" [ 0 ] ]
  in
  assert_equal_int "height zero renders no rows" 0 (List.length zero);
  let one =
    Ofzf.Render.render_lines ~terminal_height:1 ~terminal_width:80 ~query:"m" ~selected:0
      [ result "matcher" [ 0 ] ]
  in
  assert_equal_int "height one renders one row" 1 (List.length one);
  let two =
    Ofzf.Render.render_lines ~terminal_height:2 ~terminal_width:80 ~query:"m" ~selected:0
      [ result "matcher" [ 0 ] ]
  in
  assert_equal_int "height two renders two rows" 2 (List.length two);
  let cursor_middle_lines =
    Ofzf.Render.render_lines ~terminal_height:4 ~terminal_width:80 ~cursor_byte:1
      ~query:"mat" ~selected:0 [ result "matcher" [ 0 ] ]
  in
  assert_true "render lines accepts middle cursor" (List.length cursor_middle_lines > 0);
  let narrow =
    Ofzf.Render.render_lines ~terminal_height:6 ~terminal_width:1 ~query:"matcher" ~selected:0
      [ result "very-long-matcher" [ 0; 10 ] ]
  in
  assert_lines_fit ~message:"very narrow render" ~terminal_height:6 ~terminal_width:1 narrow;
  let tiny_preview =
    Ofzf.Render.render_lines ~terminal_height:2 ~terminal_width:1 ~preview:true
      ~preview_position:Ofzf.Preview.Right ~preview_content:content ~query:"m" ~selected:0
      [ result "matcher" [ 0 ] ]
  in
  assert_lines_fit ~message:"tiny preview render" ~terminal_height:2 ~terminal_width:1 tiny_preview;
  let tiny_multi =
    Ofzf.Render.render_lines ~terminal_height:3 ~terminal_width:1 ~marked_candidate_ids:[ 0 ]
      ~query:"m" ~selected:0 [ result "matcher" [ 0 ] ]
  in
  assert_lines_fit ~message:"tiny multi render" ~terminal_height:3 ~terminal_width:1 tiny_multi
