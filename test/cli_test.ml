open Test_support

let assert_cli_ok message argv expected =
  match Ofzf.Cli.parse (Array.of_list argv) with
  | Ok actual when actual = expected -> ()
  | Ok _ -> failwith (message ^ ": parsed unexpected config")
  | Error _ -> failwith (message ^ ": expected parse success")

let assert_cli_error message argv =
  match Ofzf.Cli.parse (Array.of_list argv) with
  | Ok _ -> failwith (message ^ ": expected parse error")
  | Error _ -> ()

let () =
  let open Ofzf.Cli in
  assert_cli_ok "parse interactive mode" [ "ofzf" ]
    {
      query = "";
      limit = None;
      mode = Interactive;
      preview = false;
      preview_position = Preview_right;
      multi = false;
    };
  assert_cli_ok "parse query" [ "ofzf"; "abc" ]
    {
      query = "abc";
      limit = None;
      mode = Search;
      preview = false;
      preview_position = Preview_right;
      multi = false;
    };
  assert_cli_ok "parse limit" [ "ofzf"; "--limit"; "2"; "abc" ]
    {
      query = "abc";
      limit = Some 2;
      mode = Search;
      preview = false;
      preview_position = Preview_right;
      multi = false;
    };
  assert_cli_ok "parse bench with limit" [ "ofzf"; "--bench"; "--limit"; "2"; "abc" ]
    {
      query = "abc";
      limit = Some 2;
      mode = Bench;
      preview = false;
      preview_position = Preview_right;
      multi = false;
    };
  assert_cli_ok "parse bench with limit in any order" [ "ofzf"; "--limit"; "2"; "--bench"; "abc" ]
    {
      query = "abc";
      limit = Some 2;
      mode = Bench;
      preview = false;
      preview_position = Preview_right;
      multi = false;
    };
  assert_cli_ok "parse preview right" [ "ofzf"; "--preview"; "--preview-position"; "right"; "abc" ]
    {
      query = "abc";
      limit = None;
      mode = Interactive;
      preview = true;
      preview_position = Preview_right;
      multi = false;
    };
  assert_cli_ok "parse preview bottom in any order" [ "ofzf"; "--preview-position"; "bottom"; "--preview"; "abc" ]
    {
      query = "abc";
      limit = None;
      mode = Interactive;
      preview = true;
      preview_position = Preview_bottom;
      multi = false;
    };
  assert_cli_ok "parse multi no query" [ "ofzf"; "--multi" ]
    {
      query = "";
      limit = None;
      mode = Interactive;
      preview = false;
      preview_position = Preview_right;
      multi = true;
    };
  assert_cli_ok "parse multi with initial query" [ "ofzf"; "--multi"; "abc" ]
    {
      query = "abc";
      limit = None;
      mode = Interactive;
      preview = false;
      preview_position = Preview_right;
      multi = true;
    };
  assert_cli_ok "parse multi with preview" [ "ofzf"; "--multi"; "--preview"; "abc" ]
    {
      query = "abc";
      limit = None;
      mode = Interactive;
      preview = true;
      preview_position = Preview_right;
      multi = true;
    };
  assert_cli_error "bench missing query" [ "ofzf"; "--bench" ];
  assert_cli_error "limit missing query" [ "ofzf"; "--limit"; "2" ];
  assert_cli_error "invalid limit" [ "ofzf"; "--limit"; "wat"; "abc" ];
  assert_cli_error "negative limit" [ "ofzf"; "--limit"; "-1"; "abc" ];
  assert_cli_error "invalid preview position" [ "ofzf"; "--preview"; "--preview-position"; "side"; "abc" ];
  assert_cli_error "preview position without preview" [ "ofzf"; "--preview-position"; "right"; "abc" ];
  assert_cli_error "bench preview rejected" [ "ofzf"; "--bench"; "--preview"; "abc" ];
  assert_cli_error "preview bench rejected regardless of order" [ "ofzf"; "--preview"; "--bench"; "abc" ];
  assert_cli_error "preview limit rejected" [ "ofzf"; "--preview"; "--limit"; "2"; "abc" ];
  assert_cli_error "multi bench rejected" [ "ofzf"; "--multi"; "--bench"; "abc" ];
  assert_cli_error "multi limit rejected" [ "ofzf"; "--multi"; "--limit"; "2"; "abc" ];
  assert_contains "invalid combo message" ~needle:"cannot be combined"
    (Ofzf.Cli.error_message "ofzf" Preview_conflicts_with_bench);
  assert_contains "multi invalid combo message" ~needle:"--multi cannot be combined"
    (Ofzf.Cli.error_message "ofzf" Multi_conflicts_with_limit)
