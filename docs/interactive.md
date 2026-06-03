# Interactive Mode

Interactive mode is the terminal UI layer on top of the matcher, scoring, Top-K,
and incremental search engine.

```sh
cat input.txt | ofzf
```

It remains an MVP: no preview window, no multi-select, no mouse support, no
ncurses, and no shell integration.

## Mode selection

The CLI selects interactive mode only when no query is provided. Existing modes
remain backward compatible:

```sh
cat input.txt | ofzf QUERY
cat input.txt | ofzf --limit N QUERY
cat input.txt | ofzf --bench QUERY
```

This means scripts that already pass a query keep receiving ranked matching
lines with no UI.

## Input and output streams

Interactive mode reads all stdin candidates once before entering the UI. It then
opens `/dev/tty` for raw key input and ANSI rendering. When the user presses
Enter on a selected result, only that selected candidate is printed to stdout.

This mirrors the important shell-pipeline property of fuzzy finders: UI noise
does not contaminate stdout.

## Query editing

The query starts empty. Printable character keys append one byte to the query.
Backspace removes one byte and is safe on an empty query. Every query edit runs
`Search_engine.incremental_search`:

```text
old query + candidate cache + new query
  -> exact cache hit, prefix reuse, or full fallback
  -> ranked result list
  -> selected row reset to top
```

The reuse strategy is the same one documented in `docs/search_engine.md`. If a
new query extends an old query, the previous matching subset can be reused as
the next search space.

## Selection movement

Arrow Up and Arrow Down move the selected row. Movement is clamped so selection
never goes below zero or beyond the final result.

When the query changes, selection resets to the first result. This is predictable
for the MVP and avoids stale selection indexes after a result set shrinks.

## Render loop

Each loop iteration:

1. moves the cursor to the top-left;
2. clears the terminal;
3. renders the prompt;
4. renders a stable status/help line with result count and selected index;
5. renders only the visible result window;
6. highlights matched characters from matcher positions;
7. applies ANSI inverse video to the selected row while preserving match
   highlighting;
8. reads the next key event.

The visible result window is based on terminal height where practical. The
fallback height is 20 rows. Correctness is favored over minimal redraw in this
version, so the whole visible UI is redrawn after each key. Redraws clear stale
content when the result count shrinks and the pure renderer caps output to the
detected terminal height, including very small terminal heights.

When no results are available, the result area shows a helpful empty-results
message instead of leaving stale rows visible.

## Highlighting

`Matcher.match_candidate` returns zero-based byte positions for every matched
query character. Interactive rendering uses those positions to apply a
bold/underline ANSI style to matching characters.

Selected rows use inverse video for the whole row. Highlighted characters inside
selected rows temporarily add bold/underline and then restore inverse video so
selection remains visible. ANSI styling is isolated to `Terminal` constants and
`Interactive` rendering helpers; non-interactive CLI output remains plain text.

## Alternate screen

Interactive mode enters the terminal alternate screen after raw mode starts and
leaves it during cleanup. This keeps the fuzzy-finder UI from polluting the
calling shell's scrollback. Cleanup is attempted on Enter, Escape, Ctrl-C, and
unexpected exceptions.

## Exit behavior

- Enter prints the selected candidate to stdout and exits 0 when a result is
  selected.
- Enter with no result exits non-zero and prints no selected candidate.
- Escape restores the terminal and exits non-zero.
- Ctrl-C restores the terminal and exits non-zero.
- Empty stdin prints an error and exits non-zero.
- Missing `/dev/tty` prints an error and exits non-zero.

## Memory behavior

Unlike the streaming non-interactive path, interactive mode must keep candidates
in memory because every keystroke may run another search. Memory is therefore
`O(n)` in the number and size of candidates, plus cache entries maintained by
the search context.

This is acceptable for v0.7 because the goal is UI correctness and integration
with the incremental engine. Future versions can add candidate metadata caches,
cache eviction, and background indexing.

## Current limitations

- No preview window.
- No multi-select.
- No mouse support.
- No resize handling after startup.
- Query editing is byte-based rather than grapheme-aware.
- Highlighting is byte-position-based, matching the current matcher API.
