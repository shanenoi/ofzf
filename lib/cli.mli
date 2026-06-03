(** Command-line argument parsing for [ofzf]. *)

type preview_position = Preview_right | Preview_bottom
(** Preview window placement. *)

type mode = Search | Bench | Interactive
(** CLI mode. [Search] preserves normal filter behavior. [Bench] prints
    search-engine timing and cache statistics instead of matching lines.
    [Interactive] starts the terminal UI when no query is provided. *)

type config = {
  query : string;
  limit : int option;
  mode : mode;
  preview : bool;
  preview_position : preview_position;
}
(** Parsed CLI configuration. [limit = None] means full ranking. *)

type error =
  | Missing_query
  | Invalid_limit of string
  | Negative_limit of int
  | Invalid_preview_position of string
  | Missing_preview_position
(** User-facing parse errors. *)

val parse : string array -> (config, error) result
(** Parse argv-style arguments. Supported forms are:

    - [ofzf]
    - [ofzf QUERY]
    - [ofzf --limit N QUERY]
    - [ofzf --bench QUERY]
    - [ofzf --bench --limit N QUERY]
    - [ofzf --preview [QUERY]]
    - [ofzf --preview --preview-position right|bottom [QUERY]] *)

val usage : string -> string
(** Usage text for the executable name. *)

val error_message : string -> error -> string
(** Human-readable error plus usage text. *)
