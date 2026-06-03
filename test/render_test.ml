let assert_true message value = if not value then failwith message
let contains ~needle value =
  let n = String.length needle and l = String.length value in
  let rec loop i =
    if n = 0 then true
    else if i + n > l then false
    else if String.sub value i n = needle then true
    else loop (i + 1)
  in
  loop 0

let result candidate positions = Ofzf.Matcher.{ candidate; positions; score = 0 }

let () =
  let highlighted = Ofzf.Render.render_candidate ~selected:false ~positions:[ 0; 1 ] ~candidate:"matcher" in
  assert_true "highlight contains ansi" (contains ~needle:Ofzf.Terminal.highlight highlighted);
  let selected = Ofzf.Render.render_result_line ~terminal_width:7 ~selected:true (result "matcher" [ 0 ]) in
  assert_true "selected contains inverse" (contains ~needle:Ofzf.Terminal.inverse selected);
  assert_true "ansi ignored for width"
    (Ofzf.Text_width.display_width_ansi selected <= 7);
  let unicode = Ofzf.Render.render_result_line ~terminal_width:3 ~selected:false (result "界abc" [ 0 ]) in
  assert_true "unicode clipped safely" (Ofzf.Text_width.display_width_ansi unicode <= 3);
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
  assert_true "empty result message" (List.exists (contains ~needle:"no matches") empty)
