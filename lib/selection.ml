type action = Move_up | Move_down | Page_up | Page_down | Stay

let clamp ~selected ~result_count =
  if result_count <= 0 then 0 else min (result_count - 1) (max 0 selected)

let apply_action ?(page_size = 10) action ~selected ~result_count =
  match action with
  | Move_up -> clamp ~selected:(selected - 1) ~result_count
  | Move_down -> clamp ~selected:(selected + 1) ~result_count
  | Page_up -> clamp ~selected:(selected - max 1 page_size) ~result_count
  | Page_down -> clamp ~selected:(selected + max 1 page_size) ~result_count
  | Stay -> clamp ~selected ~result_count

let selected_result ~selected results =
  let rec loop current = function
    | [] -> (None, 1)
    | value :: _ when current = selected -> (Some value, 0)
    | _ :: rest -> loop (current + 1) rest
  in
  loop 0 results

let selected_candidate_text ~selected results =
  match fst (selected_result ~selected results) with
  | None -> None
  | Some result -> Some result.Matcher.candidate

let selected_candidate_id ~selected results =
  match fst (selected_result ~selected results) with
  | None -> None
  | Some result -> Some result.Matcher.original_index

let preserve_selected_candidate_id ~previous_candidate_id ~fallback_selected results =
  match previous_candidate_id with
  | None -> clamp ~selected:fallback_selected ~result_count:(List.length results)
  | Some candidate_id ->
      let rec loop index = function
        | [] -> clamp ~selected:fallback_selected ~result_count:(List.length results)
        | result :: _ when result.Matcher.original_index = candidate_id -> index
        | _ :: rest -> loop (index + 1) rest
      in
      loop 0 results

let candidate_marked ~marked_candidate_ids ~candidate_id =
  List.exists (( = ) candidate_id) marked_candidate_ids

let normalize_marked_candidate_ids marked_candidate_ids =
  marked_candidate_ids |> List.sort_uniq compare

let toggle_candidate_id ~candidate_id ~marked_candidate_ids =
  if candidate_marked ~marked_candidate_ids ~candidate_id then
    List.filter (fun marked_candidate_id -> marked_candidate_id <> candidate_id) marked_candidate_ids
  else normalize_marked_candidate_ids (candidate_id :: marked_candidate_ids)

let marked_candidates_in_input_order ~candidates ~marked_candidate_ids =
  let marked_candidate_ids = normalize_marked_candidate_ids marked_candidate_ids in
  candidates
  |> List.mapi (fun original_index candidate ->
         if candidate_marked ~marked_candidate_ids ~candidate_id:original_index then Some candidate
         else None)
  |> List.filter_map Fun.id

let selected_candidate_outputs ~candidates ~marked_candidate_ids ~selected results =
  match marked_candidates_in_input_order ~candidates ~marked_candidate_ids with
  | _ :: _ as selected_candidates -> (selected_candidates, 0)
  | [] -> (
      match selected_candidate_text ~selected results with
      | Some candidate -> ([ candidate ], 0)
      | None -> ([], 1))
