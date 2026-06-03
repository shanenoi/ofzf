# ofzf

`ofzf` is a small fzf-like fuzzy finder written in OCaml.

The first milestone is intentionally simple: a non-interactive fuzzy filter that reads candidates from standard input and prints ranked matches.

## Goals

- Learn the core ideas behind fast fuzzy finding.
- Keep the implementation dependency-light.
- Build from a tiny CLI filter toward an interactive terminal UI.

## Current status

Implemented v0.3 ranking engine optimization:

- Case-insensitive subsequence fuzzy matching.
- Match positions for future highlighting.
- Numeric scoring with consecutive, boundary, early-match, gap, exact-match, prefix, path-depth, and length signals.
- Stable ranking that preserves input order for equal scores.
- Top-k ranking support for future interactive views without fully sorting all matches.
- Benchmark executable for measuring matching and ranking time.
- CLI entry point that filters stdin using the first command-line argument as the query.
- Unit tests for matcher, scoring, ranking, and top-k behavior.

## Usage

```sh
printf 'hello\nhelp\nworld\n' | dune exec ofzf -- he
```

Expected output:

```text
help
hello
```

## Development

```sh
dune build
```

```sh
dune exec ofzf -- query < candidates.txt
```

```sh
dune runtest
```

## Benchmark

```sh
dune exec bench/benchmark.exe -- mat < candidates.txt
```

The benchmark prints candidate count, query length, matching time, ranking time, and result count.
