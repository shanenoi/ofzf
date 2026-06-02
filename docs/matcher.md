# Matcher

## Matching algorithm

The matcher uses case-insensitive subsequence matching. A candidate matches when
every query character can be found in the same order inside the candidate.

Example:

```text
query:     fz
candidate: FuzzyZero
positions: 0, 2
```

This is intentionally cheaper than edit distance. It answers the most important
question for a fuzzy finder MVP: can the typed characters be found in order?

## Match positions

Successful matches return zero-based positions. Positions are useful now for
tests and will be useful later for UI highlighting.

```ocaml
Ofzf.Matcher.match_candidate ~query:"fz" ~candidate:"FuzzyZero"
```

returns positions `[0; 2]`.

## Scoring model

A higher score is better. The v0.1 model is simple and deterministic:

- base score: `query_length * 100`;
- bonus when a match starts at the beginning of a candidate;
- bonus when a match starts after a separator such as `/`, `-`, `_`, space, `.`,
  or `:`;
- bonus for consecutive matched characters;
- penalty for later first match;
- penalty for longer candidates.

This makes compact and natural-looking matches rise above loose matches while
remaining easy to reason about.

## Ranking

`rank` filters out non-matching candidates, then sorts remaining candidates by
descending score. Ties use candidate text in ascending order so output is stable.

## Complexity analysis

For a query of length `q`, candidate length `n`, and `m` candidates:

- matching one candidate is `O(n)`;
- scoring one successful candidate is `O(q)`;
- filtering all candidates is `O(total_input_characters)`;
- sorting matched candidates is `O(k log k)`, where `k` is the number of
  matches.

The memory cost is `O(k * q)` for match result records and position lists, plus
the input lines already held by the CLI.

## Future optimization plan

The current implementation favors clarity. Later optimization passes can improve
large-input behavior without changing the user-facing CLI:

1. Store lowercased candidates once instead of lowercasing on every query.
2. Reuse arrays or buffers for match positions to reduce allocation pressure.
3. Keep only the top visible results with a bounded heap instead of sorting every
   match.
4. Parallelize matching across candidate chunks.
5. Add early bailouts when the remaining candidate cannot satisfy the remaining
   query.
