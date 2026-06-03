(** Minimal opt-in debug logging. *)

val enabled : unit -> bool
(** [true] when [OFZF_DEBUG] is set to a non-empty, non-zero value. *)

val log : string -> unit
(** Write one debug line to stderr when enabled. Does nothing by default. *)

val logf : ('a, unit, string, unit) format4 -> 'a
(** Formatted debug logging. *)

val preview_kind_to_string : Preview.source_kind -> string
(** Stable debug label for preview source kinds. *)