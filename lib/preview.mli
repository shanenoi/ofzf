(** Preview-window layout, content loading, and rendering helpers. *)

type position = Right | Bottom
(** Supported preview placements. *)

type rect = { row : int; col : int; rows : int; cols : int }
(** One-based terminal rectangle. *)

type layout = {
  enabled : bool;
  position : position option;
  results : rect;
  preview : rect option;
}
(** Computed interactive layout. [enabled = false] means the preview is hidden. *)

type source_kind =
  | No_selection
  | Candidate_text
  | Regular_file
  | Directory
  | Missing_path
  | Unreadable_path
  | Binary_file
  | Command_output
  | Command_error
(** Preview source classification for display and tests. *)

type source = File_preview | Command_preview of string
(** Preview loading source. [Command_preview command] executes [command] without a
    shell and passes the selected candidate as one argv argument. *)

type classification =
  | Regular_file_path of string
  | Directory_path of string
  | Missing_path_value of string
  | Unreadable_path_value of string
  | Plain_text_value of string
(** Candidate path/text classification before preview content is loaded. *)

type content = {
  kind : source_kind;
  title : string;
  lines : string list;
  truncated : bool;
}
(** Loaded preview content. *)

val min_result_rows : int
val min_preview_rows : int
val min_result_cols : int
val min_preview_cols : int
val max_preview_bytes : int
(** Conservative maximum bytes read from a preview file. *)

val preview_command_timeout_ms : int
(** Conservative synchronous timeout for command preview execution. *)

val command_source : string -> source
(** Build a command-preview source for callers that should not depend on the
    variant representation. *)

val source_to_string : source -> string
(** Stable source label used by preview-state identity and diagnostics. *)

val parse_position : string -> position option
(** Parse [right] or [bottom]. *)

val position_to_string : position -> string

val compute_layout :
  terminal_rows:int -> terminal_cols:int -> preview:bool -> position:position -> layout
(** Compute result/preview areas after the two-line prompt/status header. *)

val disabled : int -> int -> layout
(** Layout helper for a disabled preview pane. *)

val looks_like_path : string -> bool
(** Heuristic used to distinguish missing paths from plain text. *)

val classify_candidate : string -> classification
(** Classify a selected candidate before loading preview content. *)

val read_file_prefix : max_bytes:int -> string -> (string * bool, string) result
(** Read at most [max_bytes] from a file. The boolean reports truncation. *)

val is_binary_looking : string -> bool
(** Best-effort binary detection for preview content. *)

val normalize_lines : string -> string list
(** Normalize CRLF/LF content into preview lines. *)

val content_of_candidate_text : string -> content
(** Build preview content for a candidate that should be rendered as plain text. *)

val content_for_selection : ?source:source -> max_bytes:int -> string option -> content
(** Load preview content for the selected candidate. File preview never executes
    commands. Command preview executes only the configured executable directly,
    without shell expansion or placeholder interpolation. *)

val no_selection_content : content
(** Prebuilt content for the no-selection preview state. *)

val content_line_count : content -> int
val clamp_scroll : scroll:int -> line_count:int -> visible_rows:int -> int
val scroll_by : scroll:int -> delta:int -> line_count:int -> visible_rows:int -> int
val scroll_status : scroll:int -> visible_rows:int -> line_count:int -> string

val format_title : scroll:int -> visible_rows:int -> content -> string
(** Format the preview title/status line. *)

val render_content_lines :
  terminal_width:int -> height:int -> scroll:int -> content -> string list
(** Render clipped preview content without borders. *)

val render_preview_lines : terminal_width:int -> selected:string option -> string list
(** Backward-compatible compact preview content, clipped to terminal width. *)
