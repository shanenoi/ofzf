type 'a item = {
  value : 'a;
  score : int;
  original_index : int;
}

let compare left right =
  match Stdlib.compare right.score left.score with
  | 0 -> Stdlib.compare left.original_index right.original_index
  | by_score -> by_score

let insert_sorted item items =
  let rec loop acc = function
    | [] -> List.rev (item :: acc)
    | current :: rest as all ->
        if compare item current <= 0 then List.rev_append acc (item :: all)
        else loop (current :: acc) rest
  in
  loop [] items

let take k items =
  let rec loop remaining acc = function
    | _ when remaining <= 0 -> List.rev acc
    | [] -> List.rev acc
    | item :: rest -> loop (remaining - 1) (item :: acc) rest
  in
  loop k [] items

let of_list ~k items =
  if k <= 0 then []
  else
    let add best item = best |> insert_sorted item |> take k in
    List.fold_left add [] items
