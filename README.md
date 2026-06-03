# ofzf

`ofzf` is a small fzf-like fuzzy finder written in OCaml.

The project now has a small interactive terminal MVP while preserving the
original non-interactive fuzzy-filter behavior.

## Goals

- Learn the core ideas behind fast fuzzy finding.
- Keep the implementation dependency-light.
- Build from a tiny CLI filter toward an interactive terminal UI.

## Current status

Implemented through v0.7 interactive highlighting and UI stabilization:

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
make test
```

## Benchmark

```sh
dune exec bench/benchmark.exe -- --limit 20 mat < candidates.txt
```

The benchmark prints candidate count, query length, limit, full-search timing,
incremental timing, candidate reduction ratio, cache hits/misses, and reuse
counts.
