(** Command-line argument parsing for [ofzf]. *)

type preview_position = Preview_right | Preview_bottom
(** Preview window placement. *)

type mode = Search | Bench | Interactive
(** CLI mode. [Search] preserves normal filter behavior. [Bench] prints
    search-engine timing and cache statistics instead of matching lines.
    [Interactive] starts the terminal UI when no query is provided or an
    interactive-only option such as [--preview] or [--multi] is used. *)

type config = {
  query : string;
  limit : int option;
  mode : mode;
  preview : bool;
  preview_position : preview_position;
  multi : bool;
}
(** Parsed CLI configuration. [limit = None] means full ranking. *)

type error =
  | Missing_query
  | Invalid_limit of string
  | Negative_limit of int
  | Invalid_preview_position of string
  | Missing_preview_position
  | Preview_position_without_preview
  | Preview_conflicts_with_bench
  | Preview_conflicts_with_limit
  | Multi_conflicts_with_bench
  | Multi_conflicts_with_limit
(** User-facing parse errors. *)

val parse : string array -> (config, error) result
(** Parse argv-style arguments. Supported forms are:

    - [ofzf]
    - [ofzf QUERY]
    - [ofzf --limit N QUERY]
    - [ofzf --bench QUERY]
    - [ofzf --bench --limit N QUERY]
    - [ofzf --preview [QUERY]]
    - [ofzf --preview --preview-position right|bottom [QUERY]]
    - [ofzf --multi [QUERY]]

    Preview mode is intentionally rejected when combined with [--bench] or
    [--limit]. [--preview-position] is valid only with [--preview]. Multi mode
    starts the interactive UI and is rejected with [--bench] or [--limit]. *)

val usage : string -> string
(** Usage text for the executable name. *)

val error_message : string -> error -> string
(** Human-readable error plus usage text. *)
