type 'a entry = {
  query : string;
  results : 'a list;
}

type 'a t = 'a entry list

let empty = []

let add ~query ~results cache =
  { query; results } :: List.filter (fun entry -> entry.query <> query) cache

let find ~query cache =
  match List.find_opt (fun entry -> entry.query = query) cache with
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
  cache
  |> List.filter (fun entry -> is_prefix ~prefix:entry.query ~query)
  |> List.fold_left better None
