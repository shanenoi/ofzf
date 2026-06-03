# Scoring

`lib/scoring.ml` converts successful fuzzy matches into numeric scores and ranks
those matches stably. `Matcher` finds match positions; `Scoring` decides which
matching candidate is more useful.

## Formula

A higher score is better:

```text
score = base
      + consecutive_bonus
      + boundary_bonus
      + early_bonus
      + exact_bonus
      + prefix_bonus
      - gap_penalty
      - path_penalty
      - length_penalty
```

Current constants:

- `base = query_length * 100`
- `consecutive_bonus = 32` for each matched character immediately after the
  previous matched character
- `boundary_bonus = 36` at candidate start
- `boundary_bonus = 28` after `/`, `_`, `-`, `.`, `:`, tab, space, or `●`
- `boundary_bonus = 24` at an ASCII CamelCase transition such as `myMatcher`
- `early_bonus = max 0 (64 - first_match_index * 4)`
- `exact_bonus = 160` when the whole candidate equals the query
- `prefix_bonus = 80` when the candidate starts with the query
- `gap_penalty = 8 * total characters skipped between matched query chars`
- `path_penalty = 16 * path separators before the first match`
- `length_penalty = candidate_length`

The base keeps longer queries naturally stronger than shorter queries. Bonuses
and penalties then decide which candidate is best among candidates that all
satisfy the same query.

## Rationale

### Consecutive-match bonus

Users often expect compact matches to rank above scattered matches.

```text
query: abc
abc.txt    > a_b_c.txt
```

Both candidates contain `a`, `b`, and `c` in order, but `abc.txt` is usually the
more intentional match.

### Gap penalty

The gap penalty is the negative counterpart to the consecutive bonus. It
subtracts points for characters skipped between matched query characters.

```text
query: abc
abc         > a_bc > a___b___c
```

This improves result quality when all candidates are technically subsequence
matches but one candidate keeps the query clustered.

### Word-boundary bonus

File and symbol names often use separators or capitalization to mark meaningful
words. Matching at those boundaries should rank well because the user is likely
trying to jump to that word.

Supported boundaries:

- path separator `/`
- underscore `_`
- dash `-`
- dot `.`
- colon `:`
- tab
- space
- bullet `●`
- ASCII CamelCase transition

Example:

```text
query: mat
src/Matcher.ml > src/rematcher.ml
```

### Exact-match bonus

An exact match is the strongest possible intent signal. When a user types the
entire candidate, that candidate should beat a longer file that merely starts
with the same text.

```text
matcher > matcher.ml
```

### Prefix bonus

Prefix matches are easy to visually confirm and often represent file-name or
symbol-name starts.

```text
matcher.ml > src/matcher.ml
```

The nested path still matches well because `/matcher` is a boundary, but the
root prefix is more direct.

### Path-aware scoring

A path with many leading directories is often less direct than a basename match.
`path_penalty` subtracts points for slash separators before the first match.

```text
matcher.ml > src/fuzzy/matcher.ml
```

This is intentionally a mild penalty: deep paths can still win when they have
better boundaries, shorter gaps, or a stronger exact/prefix signal.

### Early-match bonus

Earlier matches are usually more relevant than later matches because they are
closer to the beginning of a file name, path segment, or symbol.

```text
abc.txt > later-abc.txt
```

### Candidate-length penalty

Shorter candidates are usually easier to scan and more precise. The length
penalty nudges compact candidates upward without overriding strong boundary or
consecutive signals.

```text
abc.txt > abc-very-long-file-name.txt
```

## Ranking behavior and ties

`Scoring.rank` sorts by descending numeric score. If two matches have the same
score, it preserves the original input order using the candidate's recorded
`original_index`.

This is important for shell pipelines because the input order may already encode
useful information from tools such as `find`, `git ls-files`, or `rg --files`.

`Scoring.rank_top` uses the same comparison but keeps only the best `K` results.
It returns results in the same order those items would have had after a full
rank.

## Complexity analysis

For a query of length `q`, candidate length `n`, and `m` candidates:

- matching one candidate is `O(n)`;
- scoring one successful candidate is `O(q + first_match_index)` because it
  walks match positions and counts path separators before the first match;
- filtering all candidates is `O(total_input_characters)`;
- sorting `k` matching candidates is `O(k log k)`;
- bounded top-k is `O(k * K)` for the current insertion-list implementation;
- score memory is `O(k)` plus the stored position lists.

The scoring model does not use dynamic programming, edit distance, or
backtracking. That keeps the hot path predictable.

## Future optimization plan

Later milestones can improve speed without changing CLI behavior:

1. Cache lowercased candidates between query updates.
2. Store path metadata such as basename start and slash count once per candidate.
3. Use arrays instead of lists for positions in the hottest path.
4. Replace bounded-list top-k with a heap for large `K`.
5. Parallelize matching and scoring across chunks.
6. Add early bailouts when a candidate cannot beat the current top-k threshold.
7. Tune constants against real file lists and source-code paths.
