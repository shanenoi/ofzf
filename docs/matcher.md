# Matcher

`lib/matcher.ml` owns fuzzy subsequence matching. As of v0.2, scoring and stable
ranking live in `lib/scoring.ml`, while `Matcher` keeps the public API used by
the CLI and tests.

## Matching algorithm

The matcher uses case-insensitive subsequence matching. A candidate matches when
every query character can be found in the same order inside the candidate.

Example:

```text
query:     fz
candidate: FuzzyZero
positions: 0, 2
```

This is intentionally cheaper than edit distance. It answers the core question
for a fuzzy finder: can the typed characters be found in order?

## Match positions

Successful matches return zero-based byte positions. Positions are useful for
scoring now and for UI highlighting later.

```ocaml
Ofzf.Matcher.match_candidate ~query:"fz" ~candidate:"FuzzyZero"
```

returns positions `[0; 2]`.

## API

`Matcher` exposes:

- `match_candidate` for a single candidate;
- `matches` for a boolean check;
- `rank` for filtering and ranked output.

The record returned by `match_candidate` still includes `candidate`, `positions`,
and `score`, so existing v0.1 callers do not need to change.

## Relationship to scoring

`Matcher` finds positions. It delegates numeric scoring and stable ranking to
`Scoring`.

```text
candidate + query
  -> Matcher.find_positions
  -> Scoring.score
  -> Matcher.match_result
```

This split keeps matching easy to test independently and makes future scoring
experiments safer.

## Complexity analysis

For a query of length `q`, candidate length `n`, and `m` candidates:

- matching one candidate is `O(n)`;
- matching all candidates is `O(total_input_characters)`;
- storing positions costs `O(q)` per successful match;
- ranking matched candidates adds `O(k log k)` in `Scoring`, where `k` is the
  number of matches.

## Future optimization plan

The current matcher favors clarity. Later work can optimize without changing the
CLI contract:

1. Cache lowercase candidate strings.
2. Reuse buffers for positions.
3. Add early rejection when the remaining candidate is shorter than the
   remaining query.
4. Support top-k matching so interactive rendering does not sort every match.
5. Keep match positions in arrays to reduce list allocation overhead.
