# ofzf

`ofzf` is a small fzf-like fuzzy finder written in OCaml.

The project now has a small interactive terminal MVP while preserving the
original non-interactive fuzzy-filter behavior.

## Goals

- Learn the core ideas behind fast fuzzy finding.
- Keep the implementation dependency-light.
- Build from a tiny CLI filter toward an interactive terminal UI.

## Current status

Implemented through v0.14 Process-Level CLI Test Stabilization plus three
technical-debt stabilization passes:

- Case-insensitive subsequence fuzzy matching.
- Match positions for future highlighting.
- Numeric scoring with consecutive, boundary, early-match, gap, exact-match, prefix, path-depth, and length signals.
- Stable ranking that preserves input order for equal scores.
- Top-k ranking support without fully sorting all matches.
- Streaming CLI that processes stdin line-by-line.
- `--limit N` for bounded top-k output.
- Query cache and incremental search engine for future interactive narrowing.
- Statistics for scanned candidates, matches, cache hit/miss, and reuse counts.
- `--bench QUERY` CLI mode for full vs incremental measurements.
- Benchmark executable comparing full and incremental ranking behavior.
- Interactive mode with raw terminal input, ANSI rendering, arrow-key
  selection, Enter-to-select, Escape/Ctrl-C cancellation, and terminal
  restoration.
- Interactive match highlighting from matcher positions.
- Alternate-screen rendering with idempotent cleanup on selection, cancel, and
  errors where practical.
- Stable prompt/status layout with result counts, selected index, empty-result
  messaging, and viewport edge-case handling.
- Terminal height and width detection with safe fallbacks.
- Preferred ioctl-based terminal size detection with `LINES`/`COLUMNS`, `stty`,
  and 20x80 fallbacks when ioctl is unavailable.
- SIGWINCH-driven resize notifications so interactive redraw can respond to
  terminal changes without writing UI bytes to stdout.
- Clipped interactive row rendering so long candidates do not break layout.
- Ctrl-U query clear, Ctrl-W previous-word deletion, and safer unknown escape
  handling.
- Selection clamping and viewport recalculation after result shrink or terminal
  resize checks.
- Width-aware text helpers for safer interactive rendering of ASCII, tabs,
  basic UTF-8, combining marks, wide CJK characters, emoji fallback ranges, and
  invalid UTF-8 bytes.
- Display-width clipping for prompts and result rows so interactive rendering no
  longer clips by byte length or splits UTF-8 sequences where practical.
- Optional interactive preview foundation with right-side or bottom layouts.
- `--preview` previews readable regular files, or falls back to selected
  candidate text for non-path candidates, without executing commands.
- Preview CLI validation is deterministic: preview is rejected with `--bench`,
  `--limit`, or a standalone `--preview-position`.
- Preview content is loaded only when the selected candidate changes; rendering
  consumes already-loaded content and uses ANSI-aware width accounting.
- Interactive internals are split into smaller pure modules: `Query_edit`,
  `Selection`, `Viewport`, `Render`, and `Preview_state`.
- Query cache growth is bounded by a documented default to avoid unbounded
  incremental-session memory growth.
- The search-engine path carries successful matches through ranking so it avoids
  matching once for filtering and again for ranking where practical.
- The test suite is split by module/feature ownership and includes default
  process-level CLI smoke tests that build and exercise the real `ofzf` binary.
- `OFZF_DEBUG=1` enables concise debug logs on stderr without changing normal
  stdout output.
- Preview panes classify directories, missing paths, unreadable files, and
  binary-looking files with clear messages.
- Preview scrolling supports Alt-Up/Alt-Down, Ctrl-Y/Ctrl-E, and Ctrl-B/Ctrl-F.
- CLI entry point that filters stdin using the query argument.
- Unit tests for matcher, scoring, ranking, top-k, CLI parsing, and pure
  interactive helpers.

## Usage

```sh
printf 'hello\nhelp\nworld\n' | dune exec ofzf -- he
```

Expected output:

```text
help
hello
```

Interactive mode starts when no query is provided:

```sh
printf 'hello\nhelp\nworld\n' | dune exec ofzf --
```

The UI renders to the controlling terminal and prints only the selected line to
standard output.

## Development

```sh
make build
```

On macOS, if a Homebrew LLVM/clang install points at a stale SDK and Dune fails
with `library 'System' not found` or `library 'pthread' not found`, use:

```sh
make build-macos
```

```sh
dune exec ofzf -- query < candidates.txt
```

```sh
dune exec ofzf -- --limit 20 query < candidates.txt
```

```sh
dune exec ofzf -- --bench query < candidates.txt
```

```sh
dune exec ofzf -- < candidates.txt
```

```sh
dune exec ofzf -- --preview --preview-position right < candidates.txt
```

With preview enabled, if a selected candidate is a readable regular file path,
the preview pane shows file contents. It never executes the selected candidate
as a command.

```sh
make test
```

The test suite is split by module responsibility. `Interactive` keeps terminal
lifecycle and event-loop wiring, while pure behavior lives in focused modules
that can be tested without a real TTY.

`make test` also runs process-level CLI smoke tests against the real executable.
Those tests assert stdout/stderr separation, search output, `--limit`, `--bench`,
and argument-validation behavior without requiring a real interactive terminal.

Debug logging is opt-in and writes only to stderr:

```sh
OFZF_DEBUG=1 dune exec ofzf -- he < candidates.txt
```

Debug logs include mode selection, search/cache statistics, terminal-size/layout
events, and preview reload/source-kind information. They never log preview file
contents or full candidate lists.

## Benchmark

```sh
dune exec bench/benchmark.exe -- --limit 20 mat < candidates.txt
```

The benchmark prints candidate count, query length, limit, full-search timing,
incremental timing, candidate reduction ratio, cache hits/misses, and reuse
counts.

## License

MIT. See [LICENSE](LICENSE).
