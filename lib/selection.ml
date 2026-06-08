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

let preserve_selected_candidate ~previous_candidate ~fallback_selected results =
  match previous_candidate with
  | None -> clamp ~selected:fallback_selected ~result_count:(List.length results)
  | Some candidate ->
      let rec loop index = function
        | [] -> clamp ~selected:fallback_selected ~result_count:(List.length results)
        | result :: _ when result.Matcher.candidate = candidate -> index
        | _ :: rest -> loop (index + 1) rest
      in
      loop 0 results

let candidate_marked ~marked ~candidate = List.exists (( = ) candidate) marked

let marked_candidates_in_input_order ~candidates ~marked =
  let rec loop emitted acc = function
    | [] -> List.rev acc
    | candidate :: rest ->
        if candidate_marked ~marked ~candidate && not (candidate_marked ~marked:emitted ~candidate)
        then loop (candidate :: emitted) (candidate :: acc) rest
        else loop emitted acc rest
  in
  loop [] [] candidates

let toggle_candidate ~candidates ~candidate ~marked =
  let marked =
    if candidate_marked ~marked ~candidate then
      List.filter (fun marked_candidate -> marked_candidate <> candidate) marked
    else candidate :: marked
  in
  marked_candidates_in_input_order ~candidates ~marked

let selected_candidate_outputs ~candidates ~marked ~selected results =
  match marked_candidates_in_input_order ~candidates ~marked with
  | _ :: _ as selected_candidates -> (selected_candidates, 0)
  | [] -> (
      match selected_candidate_text ~selected results with
      | Some candidate -> ([ candidate ], 0)
      | None -> ([], 1))
