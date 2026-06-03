# Ranking

v0.3 adds a ranking engine optimization layer without changing CLI behavior.
The command still reads stdin and prints ranked matching lines:

```sh
cat input.txt | ofzf QUERY
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

This is best when every match must be displayed or consumed.

## Top-k ranking

`Topk` keeps only the best `K` candidates. It uses the same comparison as full
ranking:

1. higher score first;
2. lower original input index first when scores tie.

The current implementation is a bounded sorted list. Each inserted item is
placed into the current best list and the list is trimmed to size `K`.

For interactive fuzzy finding, this matters because the UI usually needs only
visible rows plus a small buffer. Sorting 100,000 matches just to render 40 rows
is wasted work.

## Correctness

Top-k results are returned in the same order as the first `K` results from full
ranking. Stable tie handling is preserved because every item carries its
`original_index`.

## Performance characteristics

For `k` matching candidates and requested size `K`:

- full sorting costs `O(k log k)`;
- current top-k costs `O(k * K)`;
- top-k memory is `O(K)` plus the input stream being processed.

For small UI-oriented `K`, bounded insertion is simple and effective. A future
heap can improve large-`K` behavior to `O(k log K)` without changing callers.

## Not implemented yet

Ranking optimization does not add terminal UI, raw mode, preview windows, or
multi-select. Those features should be built on top of `Matcher.rank_top` after
the ranking engine is stable.
