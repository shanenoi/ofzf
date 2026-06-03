# CLI

`ofzf` remains a non-interactive fuzzy filter. It reads candidates from standard
input, ranks matching lines for a query, and prints only the matching candidate
text.

```sh
cat input.txt | ofzf QUERY
cat input.txt | ofzf --limit N QUERY
cat input.txt | ofzf --bench QUERY
```

No terminal UI, raw mode, ncurses, preview window, or multi-select behavior is
implemented in this milestone.

## Argument handling

Supported forms:

- `ofzf QUERY` performs full ranking and prints every matching line.
- `ofzf --limit N QUERY` performs bounded top-k ranking and prints at most `N`
  matching lines.
- `ofzf --bench QUERY` prints benchmark and incremental-search statistics.

Error behavior:

- missing query prints usage to stderr and exits non-zero;
- invalid `--limit` prints a clear error to stderr and exits non-zero;
- negative `--limit` prints a clear error to stderr and exits non-zero;
- `--limit 0` prints nothing and exits successfully.

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

The limited path keeps only the current best `N` matches with `Topk.add`. This
means `ofzf --limit N QUERY` does not retain all matches and can process large
streams with memory bounded mostly by `N` and candidate size.

## Memory behavior

For total input size `S`, matching count `m`, and limit `K`:

- full ranking stores `O(m)` matched results, not all `S` input lines;
- limited ranking stores `O(K)` best results;
- both paths stream over stdin once;
- each retained result stores candidate text, match positions, score, and input
  index.

Benchmark mode is intentionally not streaming because it must run full and
incremental comparisons over the same candidate list.

## Full ranking vs limited ranking

Full ranking is best when callers need every matching line. It costs
`O(m log m)` to sort all matches and uses `O(m)` memory.

Limited ranking is best when callers need only the first page of results or a
small batch. The current bounded-list implementation costs `O(m * K)` and uses
`O(K)` memory. For small limits this avoids unnecessary allocation and sorting.

## Stable ordering

Both paths use the same ordering:

1. higher score first;
2. lower original input index first for equal scores.

Therefore, `ofzf --limit K QUERY` returns the same ordered prefix as full ranking
for the same query and input.
