# ofzf

`ofzf` is a small fzf-like fuzzy finder written in OCaml.

The first milestone is intentionally simple: a non-interactive fuzzy filter that reads candidates from standard input and prints ranked matches.

## Goals

- Learn the core ideas behind fast fuzzy finding.
- Keep the implementation dependency-light.
- Build from a tiny CLI filter toward an interactive terminal UI.

## Current status

Implemented skeleton:

- OCaml/Dune project layout.
- Basic subsequence fuzzy matcher.
- Simple scoring function.
- CLI entry point that filters stdin using the first command-line argument as the query.

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
