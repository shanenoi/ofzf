# Safe Command Preview

v0.20 implements the v0.19 safe command-preview design. The main rule is:
**preview commands are argv-based, not shell strings**.

## Goals

- Allow a selected candidate to be previewed by a user-chosen executable.
- Preserve the shell-pipeline contract: stdout is reserved only for final
  selected results.
- Avoid shell expansion, `{}` interpolation, command templates, and custom
  quoting rules in the first command-preview implementation.
- Keep preview ownership inside `Preview` / `Preview_state`; rendering still
  receives already-loaded content.
- Keep the feature testable without requiring a real interactive terminal.

## Non-goals

- No shell commands such as `sh -c 'cat {} | head'`.
- No `{}` placeholder interpolation.
- No custom quoting language.
- No streaming preview output.
- No background preview worker pool.
- No user-configurable process environment.
- No command preview for all multi-selected items; preview follows the
  highlighted row only.

## CLI shape

Implemented flag:

```sh
ofzf --preview-command cat
ofzf --preview-command cat QUERY
ofzf --preview-command cat --preview-position bottom QUERY
ofzf --multi --preview-command cat QUERY
```

`--preview-command COMMAND` implies preview mode. Requiring both
`--preview` and `--preview-command` would be more verbose without adding safety.
Passing both is harmless and parses the same as `--preview-command` alone.

Valid combinations:

- `--preview-command COMMAND`
- `--preview --preview-command COMMAND`
- `--preview-command COMMAND QUERY`
- `--preview-command COMMAND --preview-position right|bottom [QUERY]`
- `--multi --preview-command COMMAND [QUERY]`

Invalid combinations:

- `--preview-command` without `COMMAND`;
- `--preview-command ""` if the parser can observe an empty command string;
- `--preview-command --some-option`, because option-looking command values are
  treated as invalid command input;
- `--preview-command COMMAND --bench QUERY`;
- `--preview-command COMMAND --limit N QUERY`;
- `--preview-position right|bottom` without either `--preview` or
  `--preview-command`.

`--preview-command` is interactive-only. It does not change non-interactive
search, `--limit`, or `--bench` behavior.

## Command execution model

The v0.20 execution model is intentionally small:

```text
selected candidate:  "src/main.ml"
preview command:     "cat"
argv executed:       ["cat"; "src/main.ml"]
```

Implementation rules:

1. Do not run a shell by default.
2. Resolve the executable with `PATH`-style lookup or an executable path.
3. Pass the selected candidate as exactly one argv argument.
4. Do not interpolate selected text into a string.
5. Do not split selected text on whitespace.
6. Do not treat `{}` specially in v0.20.
7. Do not support fixed command arguments in v0.20.
8. Reject command values that are empty, contain whitespace, or look like CLI
   options starting with `--`.

Supporting command plus fixed arguments, for example `bat --color=always`, is
useful but should be designed separately. It needs either repeated flags, a
terminator syntax, or a minimal argv parser. Adding that parser now would create
more surface area than the first implementation needs.

## Safety model

Command preview must preserve these invariants:

- stdout from `ofzf` remains final selected results only;
- command stdout/stderr are captured and rendered inside the preview content;
- command output is never written directly to process stdout;
- command output is bounded by a byte cap;
- long-running commands time out;
- stale preview results are not shown for a newer selected candidate;
- missing commands and failures render safe messages instead of crashing the UI.

Implemented constants:

```text
max_preview_command_bytes = 256 KiB
preview_command_timeout = 500 ms
```

The byte cap matches the current file-preview cap. The timeout is short enough to
keep the interactive UI responsive while still allowing simple tools like `cat`
or `head` to complete.

Environment handling should be conservative: inherit the normal process
environment, but do not add user-configurable environment injection in v0.20.
Debug logs may include the command name, exit status, timeout flag, and captured
byte counts. They must not log full preview output.

## Runtime behavior

### File preview vs command preview

`--preview` without `--preview-command` keeps the current file/text behavior.

`--preview-command COMMAND` switches the preview source for the highlighted row
to command output. The selected candidate is still passed as data to the command,
but `Preview` no longer classifies it as a file path first.

This avoids confusing precedence such as "read file directly unless it is not a
file, then run the command". In command-preview mode, the command owns the
preview content.

### Empty selection

If there is no selected result, render the existing no-selection preview content
and do not run the command.

If the selected candidate is an empty string, run the command with the empty
string as the candidate argument:

```text
[COMMAND; ""]
```

That preserves the exact argv model and avoids adding special cases that would
be hard to explain.

### Successful command

If the command exits `0`, render captured stdout as preview content. If stdout is
empty but stderr has content, render stderr with a title that makes the source
clear. If both are empty, render `(command produced no output)`.

### Non-zero exit

If the command exits non-zero, render a safe diagnostic in the preview pane:

```text
preview command exited with status N
```

Then include captured stderr when present; otherwise include captured stdout when
present. This makes failures visible without sending command output to stderr or
stdout directly.

### Missing command

If the executable cannot be found or executed, render a safe diagnostic:

```text
preview command not found: COMMAND
```

or:

```text
preview command could not start: COMMAND
```

The UI should continue running.

### Timeout

If the command exceeds the timeout, terminate it when practical and render:

```text
preview command timed out after 500 ms
```

Captured partial output may be shown only if doing so is deterministic and still
respects the byte cap. Otherwise prefer the timeout message alone for v0.20.

### Stale previews

v0.20 remains synchronous and timeout-bounded. `Preview_state` keys loaded
content by selected candidate and command
configuration. If the selected candidate changes, the next reload replaces the
old content and resets scroll.

If an async worker is introduced later, preview results must carry a generation
or selected-candidate identity so stale command output cannot replace the current
preview.

## Architecture boundaries

Ownership:

| Module | Command-preview responsibility |
| --- | --- |
| `Cli` | Parse `--preview-command`, validate interactive-only combinations. |
| `bin/main.ml` | Pass parsed preview configuration into `Interactive`. |
| `Interactive` | Coordinate selected-candidate changes and call `Preview_state`; no process-spawn policy. |
| `Preview_state` | Cache loaded content by selected candidate and preview source configuration; reset/clamp scroll. |
| `Preview` | Own command-preview policy, argv construction, output caps, timeout handling, and content normalization. |
| `Render` | Render already-loaded `Preview.content`; no process spawning. |
| `Terminal` | No command-preview knowledge. |
| `Search_engine`, `Matcher`, `Scoring`, `Topk` | No command-preview knowledge. |

A small type keeps the boundary explicit:

```ocaml
type source =
  | File_preview
  | Command_preview of string
```

`Preview.content_for_selection` receives `source` and the selected candidate.
The existing file/text path remains the default.

## Test coverage

Parser tests cover:

- `--preview-command cat` is valid and selects interactive preview mode;
- `--preview --preview-command cat` is valid;
- `--preview-command cat --preview-position bottom` is valid;
- `--multi --preview-command cat` is valid;
- missing command is rejected;
- `--preview-command cat --bench query` is rejected;
- `--preview-command cat --limit 10 query` is rejected;
- `--preview-position right` is valid when `--preview-command cat` is present.

Preview unit tests cover:

- command argv is `[COMMAND; selected_candidate]`;
- selected candidate containing spaces is one argv argument;
- selected candidate containing `{}` is not expanded;
- successful stdout becomes preview content;
- successful empty output renders an explicit empty-output message;
- non-zero exit renders status and bounded stderr/stdout content;
- missing command renders a safe message;
- timeout renders a deterministic timeout message;
- output larger than the cap is truncated and marked as truncated;
- no-selection content does not spawn a command;
- file/text preview behavior remains unchanged when source is `File_preview`.

Process-level tests cover:

- invalid CLI combinations fail before interactive mode starts;
- stdout remains empty for preview diagnostics and validation errors;
- process tests do not require a real interactive terminal.

The command-preview test suite does not require a live TTY. Pure unit tests and
parser/process validation are enough for v0.20.

## Deferred follow-up design

These features remain deferred until the argv-only command-preview path has more
real-world usage:

- fixed command arguments;
- shell-command opt-in mode;
- `{}` placeholder interpolation;
- async preview workers and cancellation;
- streaming output into the preview pane;
- user-configurable command environment;
- preview command execution for every marked multi-select candidate.
