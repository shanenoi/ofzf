type 'a item = {
  value : 'a;
  score : int;
  original_index : int;
}

type 'a t = {
  capacity : int;
  mutable size : int;
  data : 'a item option array;
}

let compare left right =
  match Stdlib.compare right.score left.score with
  | 0 -> Stdlib.compare left.original_index right.original_index
  | by_score -> by_score

let better left right = compare left right < 0
let weaker left right = compare left right > 0

let create ~k () = {
  capacity = max 0 k;
  size = 0;
  data = Array.make (max 0 k) None;
}

let length heap = heap.size

let get heap index =
  match heap.data.(index) with
  | Some item -> item
  | None -> invalid_arg "Topk: missing heap item"

let set heap index item = heap.data.(index) <- Some item

let swap heap left right =
  let left_item = heap.data.(left) in
  heap.data.(left) <- heap.data.(right);
  heap.data.(right) <- left_item

let rec bubble_up heap index =
  if index > 0 then
    let parent = (index - 1) / 2 in
    if weaker (get heap index) (get heap parent) then (
      swap heap index parent;
      bubble_up heap parent)

let rec bubble_down heap index =
  let left = (index * 2) + 1 in
  let right = left + 1 in
  let weakest = ref index in
  if left < heap.size && weaker (get heap left) (get heap !weakest) then
    weakest := left;
  if right < heap.size && weaker (get heap right) (get heap !weakest) then
    weakest := right;
  if !weakest <> index then (
    swap heap index !weakest;
    bubble_down heap !weakest)

let push heap item =
  if heap.capacity <= 0 then ()
  else if heap.size < heap.capacity then (
    set heap heap.size item;
    heap.size <- heap.size + 1;
    bubble_up heap (heap.size - 1))
  else
    let weakest = get heap 0 in
    if better item weakest then (
      set heap 0 item;
      bubble_down heap 0)

let to_list heap =
  let rec loop index acc =
    if index < 0 then acc else loop (index - 1) (get heap index :: acc)
  in
  loop (heap.size - 1) []

let to_sorted_list heap = heap |> to_list |> List.sort compare

let of_list ~k items =
  if k <= 0 then []
  else
    let heap = create ~k () in
    List.iter (push heap) items;
    to_sorted_list heap

let add ~k best item = of_list ~k (item :: best)
