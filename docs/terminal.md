# Terminal

`Terminal` is the low-level interactive-mode layer. It is deliberately small
and dependency-free: no ncurses, no terminal UI framework, and no external OCaml
package.

## Raw mode design

Interactive mode reads candidates from stdin, but keystrokes must come from the
user's terminal. `Terminal.enter_raw_mode` therefore opens `/dev/tty` for
reading and writing. This keeps the streams separated:

- stdin remains the candidate input stream;
- `/dev/tty` receives UI rendering and key input;
- stdout remains reserved for the final selected candidate.

When raw mode starts, the previous terminal mode is saved. The raw mode disables
canonical input, echo, and terminal-generated signals so the program can receive
individual key bytes directly.

## Restoration strategy

The `Interactive` loop calls cleanup on normal Enter selection, Escape, Ctrl-C,
and unexpected exceptions. Cleanup attempts to:

1. show the cursor;
2. clear the UI area;
3. move the cursor back to the top-left;
4. leave the alternate-screen buffer if active;
5. restore the saved terminal attributes;
6. close the `/dev/tty` file descriptor.

`Terminal.restore` is idempotent, so repeated cleanup attempts are safe. It also
attempts to show the cursor and leave the alternate screen before closing the
terminal descriptor, which makes cleanup robust even if higher-level code calls
only `restore` after an error.

## Alternate screen

`Terminal.enter_alternate_screen` emits `ESC [?1049h` and records that the
handle is using the alternate buffer. `Terminal.leave_alternate_screen` emits
`ESC [?1049l` only once. The state flag keeps restoration idempotent and avoids
duplicated alternate-screen exit sequences.

## Key event handling

Raw key input is byte-oriented. The current MVP decodes:

- printable character bytes as `Character c`;
- `\r` and `\n` as Enter;
- `\b` and DEL as Backspace;
- Ctrl-B/Ctrl-F as preview page up/down;
- Ctrl-E/Ctrl-Y as preview line down/up;
- Ctrl-U as `Ctrl_u`;
- Ctrl-W as `Ctrl_w`;
- Ctrl-C as `Ctrl_c`;
- bare Escape as `Escape`;
- `ESC [ A` as Arrow Up;
- `ESC [ B` as Arrow Down;
- `ESC [ 5 ~` / `ESC [ 6 ~` as Page Up / Page Down;
- common Alt-Up / Alt-Down sequences where practical.

Escape sequences are read with a short timeout after the initial Escape byte so
a plain Escape key can still be recognized. Unsupported escape sequences become
`Unknown` key events. The interactive query editor ignores `Unknown`, which
prevents partial control bytes from corrupting the query.

## ANSI rendering helpers

The module exposes helpers for:

- clear screen;
- move cursor;
- hide cursor;
- show cursor;
- enter/leave alternate screen;
- shared style fragments for inverse-video selection and matched-character
  highlighting.

Rendering remains intentionally simple. Higher-level UI state, viewport logic,
result count formatting, and match-position highlighting belong in
`Interactive`, not in `Terminal`.

## Terminal size

Size detection first checks `LINES` and `COLUMNS`, then tries a best-effort
`stty size < /dev/tty`. If neither works, the fallback size is 20 rows by 80
columns. `normalize_size` is a pure helper used by tests and runtime fallback
logic to replace invalid dimensions.

Interactive mode asks for size on each redraw. That provides redraw-driven
resize handling without adding signal handlers or background work.

## Width behavior

Terminal width is used only by interactive rendering. Rows are clipped before
being written so long paths or candidates cannot badly break the prompt/status
layout. Non-interactive output is not clipped.

## Limitations

- Resize handling is redraw-driven rather than SIGWINCH-driven.
- No mouse input.
- No UTF-8-aware editing; Backspace removes one byte.
- No async input or background indexing.

## Unicode-safe width helpers

Terminal columns are not the same as string bytes. Interactive rendering now uses
`Text_width` to estimate visible display columns, sanitize invalid UTF-8, and
clip prompt/result text without cutting through decoded UTF-8 cells where
practical.

The terminal layer still owns raw mode, alternate-screen handling, key decoding,
and ANSI primitives. Unicode width policy lives in `Text_width`, and the UI
composition logic lives in `Interactive`.

## Preview rendering

Preview rendering uses the same ANSI-only terminal approach as the result list. The terminal layer provides primitives; `Interactive` and `Preview` decide layout, borders, clipping, and selected-candidate content. No ncurses or external UI dependency is introduced.

## Preview scrolling keys

The terminal parser recognizes the preview-scroll controls used by interactive
mode:

- Alt-Up / Alt-Down for preview line movement where terminals send common
  `ESC [1;3A/B` sequences;
- Ctrl-Y / Ctrl-E for preview line up/down;
- Ctrl-B / Ctrl-F for preview page up/down;
- Page Up / Page Down for result-list page navigation.

Unsupported escape sequences still become `Unknown` and are ignored by the
query editor so control bytes do not corrupt the query.
