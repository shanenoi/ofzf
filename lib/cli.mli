(** Command-line argument parsing for [ofzf]. *)

type mode = Search | Bench
(** CLI mode. [Search] preserves normal filter behavior. [Bench] prints
    search-engine timing and cache statistics instead of matching lines. *)

type config = {
  query : string;
  limit : int option;
  mode : mode;
}
(** Parsed CLI configuration. [limit = None] means full ranking. *)

type error = Missing_query | Invalid_limit of string | Negative_limit of int
(** User-facing parse errors. *)

val parse : string array -> (config, error) result
(** Parse argv-style arguments. Supported forms are:

    - [ofzf QUERY]
    - [ofzf --limit N QUERY]
    - [ofzf --bench QUERY]
    - [ofzf --bench --limit N QUERY] *)

val usage : string -> string
(** Usage text for the executable name. *)

val error_message : string -> error -> string
(** Human-readable error plus usage text. *)
