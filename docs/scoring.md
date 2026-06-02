# Scoring

v0.2 moves scoring into `lib/scoring.ml`. `Matcher` is responsible for finding
whether a query is a subsequence of a candidate and reporting match positions.
`Scoring` is responsible for turning those positions into a numeric score and
for producing stable ranked output.

## Formula

A higher score is better:

```text
score = base
      + consecutive_bonus
      + boundary_bonus
      + early_bonus
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
- `length_penalty = candidate_length`

The base keeps longer queries naturally stronger than shorter queries. The
bonuses then decide which candidate is the most useful among candidates that all
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

## Ranking behavior

`Scoring.rank` sorts by descending numeric score. If two matches have the same
score, it preserves the original input order using the candidate's recorded
`original_index`.

This is important for shell pipelines because the input order may already encode
useful information from tools such as `find`, `git ls-files`, or `rg --files`.

## Complexity analysis

For a query of length `q`, candidate length `n`, and `m` candidates:

- matching one candidate is `O(n)`;
- scoring one successful candidate is `O(q)` because it walks match positions;
- filtering all candidates is `O(total_input_characters)`;
- sorting `k` matching candidates is `O(k log k)`;
- score memory is `O(k)` plus the stored position lists.

The v0.2 scoring model does not use dynamic programming, edit distance, or
backtracking. That keeps the hot path predictable.

## Future optimization plan

Later milestones can improve speed without changing CLI behavior:

1. Cache lowercased candidates between query updates.
2. Use arrays instead of lists for positions in the hottest path.
3. Keep only the top visible results with a bounded heap.
4. Parallelize matching and scoring across chunks.
5. Add early bailouts when a candidate cannot beat the current top-k threshold.
6. Tune constants against real file lists and source-code paths.
