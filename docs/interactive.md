# Interactive Mode

Interactive mode is the terminal UI layer on top of the matcher, scoring, Top-K,
and incremental search engine.

```sh
cat input.txt | ofzf
```

It remains an MVP: preview is synchronous and intentionally limited, with no
multi-select, no mouse support, no ncurses, and no shell integration.

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

The query starts empty. Printable character keys append to the query through
`Query_edit`, Backspace is safe on an empty query, Ctrl-U clears, and Ctrl-W
deletes the previous whitespace-delimited word. The current UI path remains
append-oriented for compatibility, while `Query_edit` exposes cursor-aware pure
helpers for future in-query editing. Every query edit runs
`Search_engine.incremental_search`:

```text
old query + candidate cache + new query
  -> exact cache hit, prefix reuse, or full fallback
  -> ranked result list
  -> selected row kept when possible, otherwise clamped
```

The reuse strategy is the same one documented in `docs/search_engine.md`. If a
new query extends an old query, the previous matching subset can be reused as
the next search space.

## Selection movement

Arrow Up and Arrow Down move the selected row. Page Up and Page Down move by one
visible result page. `Selection` clamps movement so selection never goes below
zero or beyond the final result.

When the query changes, `Selection` preserves the previously selected candidate
when it still exists in the new result set. Otherwise it clamps the previous
index into the new range. This avoids surprising jumps while also preventing
stale selection indexes.

## Render loop

Each loop iteration detects terminal size once, then:

1. moves the cursor to the top-left;
2. clears the terminal;
3. renders the prompt;
4. renders a stable status/help line with result count and selected index;
5. renders only the visible result window;
6. highlights matched characters from matcher positions;
7. applies ANSI inverse video to the selected row while preserving match
   highlighting;
8. reads the next key event.

The visible result window is based on terminal height where practical, and rows
are clipped to terminal width where practical. The fallback size is 20x80.
Correctness is favored over minimal redraw in this version, so the whole visible
UI is redrawn after each key. Redraws clear stale content when the result count
shrinks and the pure renderer caps output to the detected terminal height,
including very small terminal heights.

`Render` owns frame generation and performs no filesystem IO. Preview content is
loaded by `Preview_state` when selection changes, then passed into render helpers
as data.

With `OFZF_DEBUG=1`, the event loop writes concise diagnostics to stderr,
including terminal size, preview layout choice, selected-candidate changes, and
preview reload source kind. Debug mode is disabled by default and never logs
preview file contents or full candidate lists.

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

Long candidates are clipped before rendering. Highlighting is applied only for
matched bytes that are inside the visible clipped range, so hidden text does not
emit unnecessary ANSI sequences.

## Terminal resize and width behavior

Interactive mode asks `Terminal.terminal_size` on every redraw. This gives a
simple synchronous resize strategy: when the terminal changes size, the next key
or redraw recalculates the viewport and keeps the selected row visible. Very
small heights produce fewer or zero result rows instead of writing past the
screen.

Prompt, status, and result rows are clipped to terminal width. This keeps long
paths from breaking the layout while preserving non-interactive output exactly
as before.

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

Query-cache growth is bounded by default, but interactive mode still retains the
candidate list itself. Future versions can add candidate metadata caches,
candidate IDs, and background indexing.

## Current limitations

- Preview is synchronous and file/text-only; command-based preview is deferred.
- No multi-select.
- No mouse support.
- Resize handling is redraw-driven rather than signal-driven.
- Query editing is byte/cell-boundary based rather than fully grapheme-aware.
- Highlighting is byte-position-based, matching the current matcher API.

## Unicode and display width

Interactive rendering now goes through `Text_width` before rows are written.
Prompt text and result rows are clipped by terminal display columns rather than
by OCaml byte length. This matters for filenames containing tabs, accents,
combining marks, CJK characters, emoji, or invalid UTF-8 bytes.

ANSI styling is applied after width clipping. The renderer therefore does not
count highlight or inverse-video escape bytes as visible columns. Matcher
positions are still byte indexes, but highlighted cells are chosen by checking
whether a matched byte falls inside each decoded display cell. ASCII candidates
keep the exact behavior from earlier versions, while UTF-8 candidates render
without cutting inside a character where practical.

## Preview foundation

When `--preview` is enabled, interactive mode asks `Preview.compute_layout` for
result and preview bounds before calculating the visible result window. The
viewport uses the actual result-pane height, so bottom preview does not borrow
rows from the preview pane and the selected row remains visible after layout is
applied. If the terminal is too small, preview is hidden and result rendering
falls back to the normal full-width result window.

Right-side preview is used by default. Bottom preview can be selected with `--preview-position bottom`. Tiny terminals hide preview rather than rendering past bounds.

## v0.12 preview file content and scrolling

When preview mode is enabled, the interactive loop asks `Preview` to load a
content record when the selected candidate changes. Rendering receives the
already-loaded content and does not perform filesystem IO while building frame
lines. The selected candidate is previewed as file content only when it is a
readable regular file. Directories, missing paths, unreadable paths,
binary-looking files, and plain text candidates render explicit fallback
messages/content.

Preview scroll state is separate from result-list selection. Alt-Up/Ctrl-Y and
Alt-Down/Ctrl-E scroll by one preview line. Ctrl-B and Ctrl-F scroll by one
preview page. Page Up and Page Down remain result-list navigation keys. The
scroll offset is clamped to the loaded content bounds and resets when the
selected candidate changes or the query is recomputed.

Preview rendering remains synchronous and ANSI-only. The current milestone still
avoids async workers, arbitrary preview commands, shell expansion, and `{}`
placeholder expansion.

Right-preview row padding uses ANSI-aware width accounting so highlight and
inverse-video escape sequences do not count as visible columns. Non-interactive
output remains unchanged.
