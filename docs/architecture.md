# Architecture

`ofzf` starts as a non-interactive fuzzy filter. The first version keeps the
program split into two layers:

```text
stdin lines + argv query
  -> bin/main.ml
  -> Ofzf.Matcher.rank
  -> ranked matching lines on stdout
```

## Components

### CLI

`bin/main.ml` owns process-level behavior:

- read every candidate line from standard input;
- read the query from the first command-line argument;
- call the matcher library;
- print only the ranked matching candidate text.

It intentionally does not know about terminal UI, raw mode, previews, or
selection state.

### Matcher library

`lib/matcher.ml` owns the core fuzzy-finding behavior:

- case-insensitive subsequence matching;
- zero-based match positions;
- numeric scoring;
- deterministic candidate ranking.

This keeps the hot path testable before any interactive UI is introduced.

## Data flow

Candidates are stored as OCaml strings. A successful match returns a small record
containing the original candidate, the match positions, and the score. The CLI
prints the original candidate text so existing shell pipelines can consume the
output directly.

## Future layers

Later milestones can build on the matcher without changing its public shape:

- interactive query updates;
- top-k ranking instead of full sorting;
- match highlighting in the renderer;
- preview windows;
- multi-select output.
