open Test_support

let size rows cols = { Ofzf.Terminal.rows; cols }

let assert_size message expected actual =
  assert_equal_int (message ^ " rows") expected.Ofzf.Terminal.rows actual.Ofzf.Terminal.rows;
  assert_equal_int (message ^ " cols") expected.Ofzf.Terminal.cols actual.Ofzf.Terminal.cols

let () =
  assert_true "parse ctrl-a" (Ofzf.Terminal.parse_key_sequence "\001" = Ofzf.Terminal.Ctrl_a);
  assert_true "parse delete" (Ofzf.Terminal.parse_key_sequence "\027[3~" = Ofzf.Terminal.Delete);
  assert_true "parse ctrl-d as delete" (Ofzf.Terminal.parse_key_sequence "\004" = Ofzf.Terminal.Delete);
  assert_true "parse arrow left" (Ofzf.Terminal.parse_key_sequence "\027[D" = Ofzf.Terminal.Arrow_left);
  assert_true "parse arrow right" (Ofzf.Terminal.parse_key_sequence "\027[C" = Ofzf.Terminal.Arrow_right);
  assert_true "parse home" (Ofzf.Terminal.parse_key_sequence "\027[H" = Ofzf.Terminal.Home);
  assert_true "parse home alternate" (Ofzf.Terminal.parse_key_sequence "\027[1~" = Ofzf.Terminal.Home);
  assert_true "parse end" (Ofzf.Terminal.parse_key_sequence "\027[F" = Ofzf.Terminal.End);
  assert_true "parse end alternate" (Ofzf.Terminal.parse_key_sequence "\027[4~" = Ofzf.Terminal.End);
  assert_size "normalize keeps positive size" (size 12 40)
    (Ofzf.Terminal.normalize_size ~fallback:(size 24 100) (size 12 40));
  assert_size "normalize replaces non-positive rows and cols" (size 24 100)
    (Ofzf.Terminal.normalize_size ~fallback:(size 24 100) (size 0 (-1)));
  assert_size "normalize replaces only invalid row" (size 24 80)
    (Ofzf.Terminal.normalize_size ~fallback:(size 24 100) (size 0 80));
  (match Ofzf.Terminal.parse_stty_size "30 120" with
  | Some parsed -> assert_size "parse standard stty size" (size 30 120) parsed
  | None -> failwith "parse standard stty size returned None");
  (match Ofzf.Terminal.parse_stty_size "  25   90  " with
  | Some parsed -> assert_size "parse padded stty size" (size 25 90) parsed
  | None -> failwith "parse padded stty size returned None");
  (match Ofzf.Terminal.parse_stty_size "0 0" with
  | Some parsed -> assert_size "parse invalid stty size normalizes" Ofzf.Terminal.fallback_size parsed
  | None -> failwith "parse invalid stty size returned None");
  assert_true "invalid stty size rejected" (Ofzf.Terminal.parse_stty_size "not a size" = None)
