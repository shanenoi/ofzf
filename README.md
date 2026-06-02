# ofzf

`ofzf` is a small fzf-like fuzzy finder written in OCaml.

The first milestone is intentionally simple: a non-interactive fuzzy filter that reads candidates from standard input and prints ranked matches.

## Goals

- Learn the core ideas behind fast fuzzy finding.
- Keep the implementation dependency-light.
- Build from a tiny CLI filter toward an interactive terminal UI.

## Current status

Implemented v0.2 advanced scoring:

- Case-insensitive subsequence fuzzy matching.
- Match positions for future highlighting.
- Numeric scoring with consecutive, boundary, early-match, and length signals.
- Stable ranking that preserves input order for equal scores.
- CLI entry point that filters stdin using the first command-line argument as the query.
- Unit tests for matcher behavior.

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
