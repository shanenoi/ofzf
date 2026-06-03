# Ranking

v0.3 adds a ranking engine optimization layer without changing CLI behavior.
The command still reads stdin and prints ranked matching lines:

```sh
cat input.txt | ofzf QUERY
cat input.txt | ofzf --limit 20 QUERY
```

## Full ranking

`Matcher.rank` filters candidates with the subsequence matcher, scores all
matches through `Scoring`, and fully sorts the matched set.

```text
candidate stream
  -> fuzzy match positions
  -> numeric score
  -> sort by score desc, original index asc
```

This is best when every match must be displayed or consumed. The CLI processes
stdin line-by-line and stores only successful matches before the final sort.

## Top-k ranking

`Topk` keeps only the best `K` candidates. The CLI uses it for
`ofzf --limit K QUERY` while reading stdin line-by-line. It uses the same
comparison as full ranking:

1. higher score first;
2. lower original input index first when scores tie.

The current implementation is a bounded sorted list. Each inserted item is
placed into the current best list and the list is trimmed to size `K`.

For interactive fuzzy finding, this matters because the UI usually needs only
visible rows plus a small buffer. Sorting 100,000 matches just to render 40 rows
is wasted work.

## Correctness

Top-k results are returned in the same order as the first `K` results from full
ranking. Stable tie handling is preserved because every retained item carries
its `original_index`, which is assigned from the original stdin order.

## Performance characteristics

For `k` matching candidates and requested size `K`:

- full sorting costs `O(k log k)`;
- current top-k costs `O(k * K)`;
- top-k memory is `O(K)` plus the current input line being processed.

For small UI-oriented or CLI `K`, bounded insertion is simple and effective. A
future heap can improve large-`K` behavior to `O(k log K)` without changing
callers.

## Streaming CLI tradeoff

The default CLI path cannot print until it has seen all input, because a later
candidate may rank above an earlier one. It still avoids storing non-matches.

The `--limit` path keeps only the best `K` matches at any time. This is the
scalable path for large streams when callers only need a short ranked prefix.

## Not implemented yet

Ranking optimization does not add terminal UI, raw mode, preview windows, or
multi-select. Those features should be built on top of `Matcher.rank_top` after
the ranking engine is stable.
