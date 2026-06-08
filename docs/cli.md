# CLI

`ofzf` supports the original non-interactive fuzzy-filter modes plus an
interactive terminal mode when no query is provided.

```sh
cat input.txt | ofzf QUERY
cat input.txt | ofzf --limit N QUERY
cat input.txt | ofzf --bench QUERY
cat input.txt | ofzf
```

No ncurses, multi-select behavior, mouse support, background indexing, or shell
integration is implemented in this milestone.

## Argument handling

Supported forms:

- `ofzf QUERY` performs full ranking and prints every matching line.
- `ofzf --limit N QUERY` performs bounded top-k ranking and prints at most `N`
  matching lines.
- `ofzf --bench QUERY` prints benchmark and incremental-search statistics.
- `ofzf` reads stdin candidates once, starts interactive mode on `/dev/tty`, and
  prints only the selected candidate to stdout.

Error behavior:

- missing query in option-driven modes such as `--bench` or `--limit N` prints
  usage to stderr and exits non-zero;
- invalid `--limit` prints a clear error to stderr and exits non-zero;
- negative `--limit` prints a clear error to stderr and exits non-zero;
- `--limit 0` prints nothing and exits successfully.
- empty stdin in interactive mode prints a clear error and exits non-zero;
- unavailable controlling terminal in interactive mode prints a clear error and
  exits non-zero.

## Interactive mode

Interactive mode is selected only by the no-query form:

```sh
cat input.txt | ofzf
```

The candidate list is read from stdin before raw mode starts. The UI opens
`/dev/tty`, enters raw mode, renders with ANSI escape sequences, and restores
the previous terminal mode on Enter, Escape, Ctrl-C, and errors where practical.

Supported keys:

- printable characters insert at the query cursor;
- Left/Right moves the query cursor;
- Home/Ctrl-A and End/Ctrl-E move to query start/end;
- Backspace removes before the cursor;
- Delete/Ctrl-D removes at the cursor;
- Ctrl-U clears the query;
- Ctrl-W deletes the previous whitespace-delimited query word;
- Arrow Up/Down moves the selected row;
- Page Up/Page Down moves the selected row by a visible page where supported;
- Enter prints the selected candidate to stdout and exits successfully;
- Escape exits non-zero;
- Ctrl-C exits non-zero.

The result window is based on terminal height and width where practical. If size
cannot be detected, `ofzf` falls back to a safe default. The UI uses the
alternate screen, clips long rows, highlights matched characters, shows the
match count and selected index, and leaves stdout reserved for the selected
candidate only.

If Enter is pressed while there are no results, interactive mode exits non-zero
without printing a selected line. Escape and Ctrl-C also cancel with non-zero
status after attempting terminal cleanup.

## Benchmark mode

`--bench QUERY` reads stdin into memory and compares the normal full-search path
with a simulated incremental session. For query `matcher`, the benchmark path
searches prefixes such as `m`, `ma`, `mat`, and so on until the full query. This
exercises `Search_engine` and `Query_cache` without adding any interactive UI.

Benchmark output includes:

- query;
- candidate count;
- matched count;
- full-search matching and ranking time;
- cache hits and misses;
- incremental reuse count;
- candidate reduction ratio.

## Streaming design

The CLI now processes stdin line-by-line. Each input line receives a monotonically
increasing original index. That index is carried through ranking so equal scores
preserve upstream order.

The full-ranking path still needs to keep every matching line because it must
sort all matches before output. It does not need to keep non-matching candidates.

The limited path keeps only the current best `N` matches with a `Topk` heap
accumulator. This means `ofzf --limit N QUERY` does not retain all matches and
can process large streams with memory bounded mostly by `N` and candidate size.

## Memory behavior

For total input size `S`, matching count `m`, and limit `K`:

- full ranking stores `O(m)` matched results, not all `S` input lines;
- limited ranking stores `O(K)` best results;
- both paths stream over stdin once;
- each retained result stores candidate text, match positions, score, and input
  index.

Benchmark and interactive modes intentionally retain the candidate list:
benchmark mode needs repeated comparisons over the same candidates, while
interactive mode needs fast re-searching on each query edit.

## Full ranking vs limited ranking

Full ranking is best when callers need every matching line. It costs
`O(m log m)` to sort all matches and uses `O(m)` memory.

Limited ranking is best when callers need only the first page of results or a
small batch. The heap-backed implementation costs `O(m log K)` and uses `O(K)`
memory. This avoids retaining or fully sorting every match while preserving the
same ordered prefix as full ranking.

## Stable ordering

Both paths use the same ordering:

1. higher score first;
2. lower original input index first for equal scores.

Therefore, `ofzf --limit K QUERY` returns the same ordered prefix as full ranking
for the same query and input.

## Query cache memory behavior

Interactive and benchmark paths use `Query_cache` through `Search_engine`. The
cache now has a bounded default size and deterministic oldest-entry eviction.
This keeps long interactive sessions from accumulating unbounded query subsets
while preserving exact lookup and longest-prefix reuse behavior.

## Unicode rendering note

Non-interactive CLI output is unchanged: matching lines are printed exactly as
provided on stdin. Width-aware clipping is only used by interactive rendering so
scripts and pipelines do not observe altered candidate text.

## Preview options

Interactive preview mode is available with `--preview`. If the selected
candidate is a readable regular file path, the preview shows file contents.
Otherwise it shows a clear fallback for directories, missing paths, unreadable
paths, binary-looking files, or plain text candidate values.

```sh
cat input.txt | ofzf --preview
cat input.txt | ofzf --preview --preview-position right
cat input.txt | ofzf --preview --preview-position bottom mat
```

`--preview-position` accepts `right` or `bottom`. Invalid values exit non-zero
with a clear message. `--preview-position` is valid only when `--preview` is
also present. `--preview` is intentionally rejected with `--bench` and with
`--limit N`; benchmark mode and top-k streaming mode stay non-interactive.
External preview commands, shell expansion, and `{}` placeholder expansion are
intentionally out of scope.

The validation pass is order-independent: `--bench --preview QUERY` and
`--preview --bench QUERY` fail with the same conflict, and valid preview-position
forms work regardless of option order.

Preview scrolling keys:

- Alt-Up or Ctrl-Y scrolls one preview line up;
- Alt-Down or Ctrl-E scrolls one preview line down;
- Ctrl-B scrolls one preview page up;
- Ctrl-F scrolls one preview page down.

## Option compatibility rules

The CLI parser validates option combinations after parsing raw flags, so order
does not change behavior.

- `--bench --limit N QUERY` is valid and benchmarks limited ranking.
- `--preview-position right|bottom` requires `--preview`.
- `--preview --bench QUERY` and `--bench --preview QUERY` are both rejected.
- `--preview --limit N QUERY` is rejected because preview is interactive and
  `--limit` belongs to non-interactive/benchmark top-k paths.
- invalid `--preview-position` values are rejected before interactive mode starts.

## Debug mode

`OFZF_DEBUG=1` enables concise diagnostic logs on stderr. Debug mode does not
change stdout, which remains reserved for ranked candidates in non-interactive
mode or the selected candidate in interactive mode. Debug logs avoid file
contents and large candidate lists.

## Process-level smoke tests

`make test` runs `test/cli_process_test.ml` against the real `ofzf` executable by
default. The Dune test stanza builds `bin/main.exe`, sets `OFZF_TEST_BIN` for the
process test, and keeps parser-only tests separate from executable smoke tests.

The process tests cover ranked search output, `--limit`, `--limit 0`, `--bench`,
debug stderr behavior, invalid CLI combinations, and preview validation that can
fail safely without a real interactive terminal. Search results remain on stdout;
usage, validation, debug, and terminal-startup messages remain on stderr.
