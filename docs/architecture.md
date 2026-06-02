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
- compatibility wrapper around ranking for the CLI.

### Scoring library

`lib/scoring.ml` owns relevance scoring and stable ordering:

- consecutive-match bonus;
- boundary bonus for path, word, bullet, whitespace, and CamelCase boundaries;
- early-match bonus;
- candidate-length penalty;
- tie handling by original input order.

This separation keeps matching mechanics independent from ranking policy.

## Ranking behavior

Candidates that do not match are removed. Matching candidates are scored and
sorted by descending score. Equal scores preserve the original input order rather
than alphabetizing. This makes the tool predictable in pipelines where upstream
order may matter.

## Complexity analysis

For `m` candidates, total input size `N`, query length `q`, and `k` matches:

- matching is `O(N)`;
- scoring is `O(k * q)`;
- ranking is `O(k log k)`;
- memory is `O(m)` for CLI input plus `O(k * q)` for match positions.

No terminal UI exists yet, so there is no rendering loop or raw-mode state.

## Future optimization plan

The architecture leaves room for fzf-style speed improvements:

1. Cache normalized candidate data once after stdin is loaded.
2. Keep only top-k visible matches for interactive rendering.
3. Parallelize scoring across chunks.
4. Add a terminal UI layer above `Matcher.rank`.
5. Add highlight rendering from match positions.
6. Add preview windows and multi-select only after the matching core is stable.
