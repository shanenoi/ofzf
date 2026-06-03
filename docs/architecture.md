# Architecture

`ofzf` is currently a non-interactive fuzzy filter. It reads candidates from
standard input, ranks matches for a query, and prints only matching lines.

```text
stdin line stream + argv query/options
  -> bin/main.ml
  -> Ofzf.Cli.parse
  -> Ofzf.Matcher.match_candidate per line
  -> full sort or Topk.add
  -> ranked matching lines on stdout
```

## Components

### CLI

`bin/main.ml` owns process-level behavior:

- parse `QUERY` or `--limit N QUERY`;
- read candidate lines from standard input one at a time;
- match and score each line as it arrives;
- keep every match for full ranking, or only the best `N` for limited ranking;
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

`lib/topk.ml` maintains a bounded list of the best results. It orders by score
descending and then by original input index ascending. The CLI uses `Topk.add`
for `--limit N`, so limited searches do not retain every matching candidate.

### CLI parser

`lib/cli.ml` parses process arguments and centralizes usage/error messages. It
keeps command-line behavior testable without spawning a process.

### Benchmark executable

`bench/benchmark.ml` reads candidates from stdin and prints:

- candidate count;
- query length;
- limit;
- matching count;
- matching time;
- full ranking time;
- top-k ranking time;
- full and top-k result counts.

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
- full ranking is `O(k log k)` and stores `O(k)` matched results;
- top-k streaming is `O(k * K)` with the current small bounded-list
  implementation, where `K` is the requested result count;
- full CLI memory is `O(k)` retained matches;
- limited CLI memory is `O(K)` retained matches.

The top-k implementation avoids allocating a full sorted result list when a
caller only needs the best `K` candidates. A future heap can reduce the top-k
bound to `O(k log K)` while preserving the same public API.

No terminal UI exists yet, so there is no rendering loop or raw-mode state.

## Future optimization plan

The architecture leaves room for fzf-style speed improvements:

1. Replace list positions with arrays or reusable buffers on hot paths.
2. Cache normalized candidate metadata in future interactive sessions.
3. Upgrade top-k from bounded insertion list to a binary heap for large `K`.
4. Add early bailouts when a candidate cannot beat the top-k threshold.
5. Parallelize scoring across chunks for non-streaming batch use cases.
6. Add a terminal UI layer above the streaming/top-k core.
7. Add highlight rendering from match positions.
8. Add preview windows and multi-select only after the matching core is stable.
