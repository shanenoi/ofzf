# Architecture

`ofzf` is currently a non-interactive fuzzy filter. It reads candidates from
standard input, ranks matches for a query, and prints only matching lines.

```text
stdin lines + argv query
  -> bin/main.ml
  -> Ofzf.Matcher.rank
  -> Ofzf.Scoring.rank
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

`lib/matcher.ml` owns fuzzy matching:

- case-insensitive subsequence matching;
- zero-based byte match positions;
- a stable public `match_result` API;
- compatibility wrappers around full ranking and top-k ranking.

Matcher does not decide ranking policy. It finds positions and delegates score
calculation to `Scoring`.

### Scoring library

`lib/scoring.ml` owns relevance scoring and stable ordering:

- consecutive-match bonus;
- boundary bonus for path, word, bullet, whitespace, and CamelCase boundaries;
- early-match bonus;
- gap penalty;
- exact-match bonus;
- prefix bonus;
- path-depth penalty;
- candidate-length penalty;
- tie handling by original input order.

### Top-k library

`lib/topk.ml` maintains a bounded list of the best results. It orders by
score descending and then by original input index ascending. This lets future
interactive views keep only visible results without fully sorting every match.

The current CLI still calls full ranking so its behavior remains unchanged.
Top-k exists as an engine-level optimization primitive.

### Benchmark executable

`bench/benchmark.ml` reads candidates from stdin and prints:

- candidate count;
- query length;
- matching count;
- matching time;
- ranking time;
- ranked count.

This gives each ranking milestone a simple regression check before terminal UI
exists.

## Ranking behavior

Candidates that do not match are removed. Matching candidates are scored and
sorted by descending score. Equal scores preserve the original input order rather
than alphabetizing. This makes the tool predictable in pipelines where upstream
order may matter.

## Complexity analysis

For `m` candidates, total input size `N`, query length `q`, and `k` matches:

- matching is `O(N)`;
- scoring is `O(k * q)`;
- full ranking is `O(k log k)`;
- top-k ranking is `O(k * K)` with the current small bounded-list
  implementation, where `K` is the requested result count;
- memory is `O(m)` for CLI input plus `O(k * q)` for match positions.

The top-k implementation avoids allocating a full sorted result list when a
caller only needs the best `K` candidates. A future heap can reduce the top-k
bound to `O(k log K)` while preserving the same public API.

No terminal UI exists yet, so there is no rendering loop or raw-mode state.

## Future optimization plan

The architecture leaves room for fzf-style speed improvements:

1. Cache normalized candidate data once after stdin is loaded.
2. Replace list positions with arrays or reusable buffers on hot paths.
3. Upgrade top-k from bounded insertion list to a binary heap for large `K`.
4. Parallelize scoring across chunks.
5. Add early bailouts when a candidate cannot beat the top-k threshold.
6. Add a terminal UI layer above `Matcher.rank_top`.
7. Add highlight rendering from match positions.
8. Add preview windows and multi-select only after the matching core is stable.
