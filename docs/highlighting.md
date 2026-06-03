# Highlighting

Interactive highlighting is intentionally built on top of the existing matcher
API. The matcher already returns zero-based byte positions for every successful
query character, so the UI does not need a second matching pass.

```text
query: mat
candidate: src/matcher.ml
positions: 4, 5, 6
```

## Rendering design

The interactive renderer receives ranked `Matcher.match_result` values. Each
result contains:

- candidate text;
- match positions;
- numeric score.

`Interactive.render_candidate` walks the candidate string once and wraps bytes
whose indexes appear in the position list with the shared terminal highlight
style. The helper is pure, so highlighting behavior can be unit-tested without a
real terminal.

`Interactive.render_candidate_clipped` uses the same styling rules but walks
only the visible byte range for the current terminal width. Match positions that
fall outside that clipped range are ignored for the current redraw.

## ANSI styling strategy

ANSI escape sequences stay in terminal/interactive rendering code:

- `Terminal.highlight` starts matched-character emphasis;
- `Terminal.end_highlight` ends emphasis in normal rows;
- `Terminal.inverse` marks the selected row;
- `Terminal.selected_end_highlight` ends matched-character emphasis while
  restoring inverse video;
- `Terminal.reset` clears styling at the end of selected rows.

Non-interactive CLI output remains plain candidate text and never receives ANSI
styling.

## Selected-row interaction

The selected row uses inverse video across the whole row. Matched characters
inside that row add bold/underline. After each highlighted character, rendering
restores inverse video instead of resetting all styles. This preserves both
signals:

- the row is still visibly selected;
- the matched characters are still visibly emphasized.

## Clipped rows

Long candidates are clipped before being written to the terminal. Clipping is
byte-based because matcher positions are currently byte offsets. ANSI escape
sequences are emitted only around visible bytes, so hidden matched characters do
not leak styling into the output. Prompt and status rows use plain clipping;
candidate rows use highlight-aware clipping.

## Complexity

For candidate length `n` and query length `q`, rendering one highlighted row is
`O(n * q)` with the current small list-position lookup. Since the UI renders
only visible rows, this is acceptable for the MVP.

Future versions can store positions in arrays or a byte mask to make rendering
`O(n)` while keeping the public matcher result stable.

## Limitations

- Positions are byte offsets, not grapheme clusters.
- Control characters in candidates are not specially escaped yet.
- Highlighting is applied only in interactive mode.
- Clipping is based on byte count, not terminal cell width.

## UTF-8 and clipped highlights

Matcher positions are byte indexes. For ASCII this maps one-to-one with terminal
characters. For UTF-8 text, the renderer decodes candidates into display cells
before applying styling. A cell is highlighted when a match byte falls inside
that cell.

Clipping happens before ANSI styling and uses display width. This prevents a
highlighted wide character from being split by byte length and prevents hidden
matches outside the clipped range from emitting stray ANSI sequences.

Selected rows still wrap the full visible row in inverse video. When a matched
cell appears inside a selected row, the match style is closed with a sequence
that restores inverse video so selection remains readable.
