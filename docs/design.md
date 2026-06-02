# Design notes

## Why fuzzy finders feel fast

A fast fuzzy finder avoids expensive work in the hot path.

The first implementation uses a cheap subsequence match:

```text
query:     abc
candidate: axbyc
match:     a b c in order
```

This is much cheaper than edit distance and good enough for an MVP.

## Initial architecture

```text
stdin candidates
  -> store as lines
  -> fuzzy_match query candidate
  -> score matching candidates
  -> sort by score
  -> print results
```

## Planned milestones

### v0.1: Non-interactive fuzzy filter

- Read candidates from stdin.
- Accept query from command-line argument.
- Print ranked matches.

### v0.2: Advanced scoring

- Separate scoring from matching.
- Add consecutive, boundary, early-match, and length-based score signals.
- Preserve input order for ties.

### v0.3: Interactive query loop

- Put terminal in raw mode.
- Capture typed characters.
- Redraw top visible matches.

### v0.4: Selection

- Arrow-key navigation.
- Enter prints selected item.
- Escape exits.

### v0.5: Large-input optimization

- Avoid needless allocations.
- Reuse buffers.
- Keep top-k results instead of sorting everything.
