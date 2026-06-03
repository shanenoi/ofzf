# Terminal Hardening

v0.8 hardens the interactive MVP without adding large product features. The
focus is making raw ANSI rendering safer when terminal dimensions, input
sequences, or result sets change.

## Resize strategy

The renderer asks `Terminal.terminal_size` on each redraw. Size detection checks
`LINES` and `COLUMNS`, then tries `stty size < /dev/tty`, and finally falls back
to `20x80`. This keeps resize handling simple and synchronous: no signal handler
or async redraw loop is needed yet.

After each detected size change, the visible window is recalculated from the
current selected row. The selected row remains visible by choosing the smallest
window start that still contains it. Very small heights are handled by returning
zero result rows rather than writing past the terminal bottom.

## Row clipping strategy

Interactive result rows are clipped to the detected terminal width before they
are written. Current rendering clips by display width through `Text_width` while
still mapping byte-based matcher positions onto decoded cells. ANSI style bytes
are emitted only around visible cells, so hidden characters do not receive
highlight sequences and long candidates cannot push the layout horizontally.

Prompt and status rows are also clipped. Non-interactive CLI output is unchanged
and never receives ANSI styling or truncation.

## Highlighting with clipping

`Interactive.render_candidate_clipped` walks only the visible byte range. If a
matched byte is inside that range, the renderer emits the match highlight style.
If a matched byte is outside the clipped range, it is ignored for that redraw.
Selected rows still use inverse video, and matched bytes inside selected rows
restore inverse video after the highlight ends.

## Input control handling

The key parser now treats Ctrl-U and Ctrl-W as first-class key events:

- Ctrl-U clears the whole query.
- Ctrl-W deletes the previous whitespace-delimited word.
- Backspace remains safe on an empty query.
- Escape and Ctrl-C remain cancellation paths.
- Unknown escape/control sequences are returned as `Unknown` and ignored by query
  editing, so they do not corrupt the query text.

The current parser is still intentionally small. Unsupported terminal sequences
are ignored rather than partially interpreted.

## Redraw cleanup

Interactive redraw still favors correctness over clever partial updates. Each
iteration moves the cursor to the top-left, clears the alternate screen, and
renders only the rows that fit within the current terminal height. This removes
stale rows when result counts shrink and keeps prompt/status/result layout
stable.

Cleanup is idempotent. On handled exits and errors, the UI attempts to show the
cursor, clear the screen, leave the alternate screen, restore terminal mode, and
close `/dev/tty`.

## Selection clamping

Selection movement and query edits clamp the selected index into the current
result range:

- Arrow Up at the top stays at the top.
- Arrow Down at the bottom stays at the bottom.
- When a query change leaves enough results, the same selected index is kept.
- When the result count shrinks below the old selected index, selection clamps to
  the final available result.
- Enter with no result exits non-zero and prints no selected output.

## Current limitations

- Resize is detected on redraw rather than via SIGWINCH.
- Clipping is display-width-aware but still approximate, not full grapheme-cluster aware.
- Long ANSI-highlighted rows are clipped before writing, but candidate control
  characters are not escaped yet.
- Preview is synchronous and file/text-only. Multi-select, mouse support, async
  indexing, background workers, shell integration, and command preview remain
  deferred.

## v0.10 width hardening

The v0.8 clipping path used byte length as a proxy for terminal width. v0.10
replaces that with display-width clipping for the prompt and result rows.

The new behavior:

- clips by estimated terminal columns;
- does not count ANSI styling bytes as visible width;
- avoids splitting valid UTF-8 byte sequences where practical;
- replaces invalid UTF-8 with `�` rather than emitting broken bytes;
- keeps highlighted match cells readable inside selected rows.

This remains a pragmatic implementation. It is not a complete Unicode
`wcwidth`/grapheme engine, but it is safer for real-world filenames than byte
clipping.
