# Search Engine

`Search_engine` is the reusable engine behind benchmark mode and the
interactive terminal MVP. It sits above `Matcher`, `Scoring`, and `Topk`.

```text
candidate list + query + search_context
  -> choose full input, previous subset, or cached subset
  -> matcher produces successful matches with positions and scores
  -> rank all results or rank top-k from the matched records
  -> updated search_context + statistics
```

No raw-mode or rendering behavior is part of this layer; terminal concerns live
in `Terminal` and `Interactive`.

## Full search

`full_search` scans the complete candidate list, filters matches, ranks them,
and records statistics. It is the fallback for unrelated query changes.

```text
query: sc
source: all candidates
```

## Incremental search

`incremental_search` reuses prior work when the new query extends an older one.

Example:

```text
m    scans all candidates
ma   scans only candidates that matched m
mat  scans only candidates that matched ma
matc scans only candidates that matched mat
```

This is correct because fuzzy subsequence matching is monotonic with respect to
query extension: if a candidate does not match `ma`, it cannot match `mat`.

## Reuse strategy

The engine chooses the search space in this order:

1. exact cache hit for the requested query;
2. longest cached prefix of the requested query;
3. previous query/subset when the previous query is a prefix;
4. full candidate list fallback.

Exact cache hits reuse the cached candidate subset and rebuild match records for
the requested output mode. Prefix reuse still performs matching because the
longer query may reject some candidates from the shorter query. The internal
pipeline carries successful `Matcher.match_result` values into ranking so a
search pass does not separately match once for filtering and again for ranking.

## Statistics

Each result includes statistics for observability:

- `candidate_count_scanned`;
- `candidates_matched`;
- `cache_hits`;
- `cache_misses`;
- `incremental_reuse_count`;
- `matching_time`;
- `ranking_time`.

The context carries accumulated cache hit/miss and reuse counters so a simulated
or future interactive session can report cache effectiveness across keystrokes.

## CLI benchmark mode

`ofzf --bench QUERY` reads stdin into memory and simulates typing the query
prefix-by-prefix. It prints the normal full-search timing plus cache and
incremental counters from the simulated incremental path.

Normal query-based CLI search remains streaming. Benchmark and interactive modes
retain the candidate list so they can compare or repeat searches over the same
input.

## Complexity analysis

For full input size `N`, previous matching subset size `P`, final match count
`m`, query length `q`, and optional limit `K`:

- full matching scans `O(N)` candidate bytes;
- incremental prefix matching scans `O(P)` candidate bytes;
- exact cache hits scan `O(0)` candidates and re-rank cached matches;
- full ranking costs `O(m log m)`;
- top-k ranking costs `O(m * K)` with the current bounded-list implementation;
- context memory is proportional to the bounded cached matching subsets.

Incremental search is most valuable when each typed character sharply reduces
`P`, which is common for file paths and symbol-like candidates.

## Debug behavior

Search-engine statistics are surfaced by the CLI when `OFZF_DEBUG=1` is set.
Debug logs report aggregate counts such as matched candidates, cache hits,
cache misses, and reuse counts. They do not print full candidate lists.
