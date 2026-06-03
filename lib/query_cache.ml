type 'a entry = {
  query : string;
  results : 'a list;
}

type 'a t = {
  max_entries : int;
  entries : 'a entry list;
}

let default_max_entries = 64

let create ?(max_entries = default_max_entries) () = {
  max_entries = max 0 max_entries;
  entries = [];
}

let empty = create ()

let entries cache = cache.entries
let max_entries cache = cache.max_entries

let take count values =
  let rec loop remaining acc = function
    | _ when remaining <= 0 -> List.rev acc
    | [] -> List.rev acc
    | value :: rest -> loop (remaining - 1) (value :: acc) rest
  in
  loop count [] values

let add ~query ~results cache =
  if cache.max_entries <= 0 then { cache with entries = [] }
  else
    let entries =
      { query; results } :: List.filter (fun (entry : _ entry) -> entry.query <> query) cache.entries
    in
    { cache with entries = take cache.max_entries entries }

let find ~query cache =
  match List.find_opt (fun (entry : _ entry) -> entry.query = query) cache.entries with
  | None -> None
  | Some entry -> Some entry.results

let is_prefix ~prefix ~query =
  let prefix_length = String.length prefix in
  let query_length = String.length query in
  prefix_length <= query_length
  && String.sub query 0 prefix_length = prefix

let longest_prefix ~query cache =
  let better current candidate =
    match current with
    | None -> Some candidate
    | Some best ->
        if String.length candidate.query > String.length best.query then Some candidate
        else current
  in
  cache.entries
  |> List.filter (fun (entry : _ entry) -> is_prefix ~prefix:entry.query ~query)
  |> List.fold_left better None
