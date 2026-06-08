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
- Delete/Ctrl-D as query delete-at-cursor;
- Ctrl-A/Ctrl-E as query start/end when preview mode does not consume Ctrl-E
  for scrolling;
- Ctrl-B/Ctrl-F as preview page up/down;
- Ctrl-E/Ctrl-Y as preview line down/up;
- Ctrl-U as `Ctrl_u`;
- Ctrl-W as `Ctrl_w`;
- Ctrl-C as `Ctrl_c`;
- bare Escape as `Escape`;
- `ESC [ A` as Arrow Up;
- `ESC [ B` as Arrow Down;
- `ESC [ C` / `ESC [ D` as Arrow Right / Arrow Left;
- common Home / End sequences;
- `ESC [ 3 ~` as Delete;
- `ESC [ 5 ~` / `ESC [ 6 ~` as Page Up / Page Down;
- common Alt-Up / Alt-Down sequences where practical;
- SIGWINCH resize notifications as `Resize` events.

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

Rendering remains intentionally simple. Higher-level UI state belongs in
`Interactive`; pure viewport logic belongs in `Viewport`; ANSI frame composition
belongs in `Render`; preview content/scroll state belongs in `Preview_state`.
`Terminal` stays focused on raw mode, key decoding, size detection, and ANSI
primitives.

## Terminal size

Size detection prefers ioctl `TIOCGWINSZ` on the active `/dev/tty` handle when
interactive mode has one. If that is unavailable, it tries ioctl on `/dev/tty`,
then `LINES`/`COLUMNS`, then a best-effort `stty size < /dev/tty`. If none of
those work, the fallback size is 20 rows by 80 columns. `normalize_size` and
`parse_stty_size` are pure helpers used by tests and runtime fallback logic.

Interactive mode detects size once per event/render iteration and passes that
size through viewport and render helpers. That avoids repeated terminal-size
lookups within one frame. `Terminal.enter_raw_mode` installs a SIGWINCH handler
that marks a pending resize; the next interrupted/observed read becomes a
`Resize` event so the loop can redraw with fresh dimensions without mixing UI
output into stdout.

## Width behavior

Terminal width is used only by interactive rendering. Rows are clipped before
being written so long paths or candidates cannot badly break the prompt/status
layout. Non-interactive output is not clipped.

## Limitations

- Resize handling is SIGWINCH-aware but still redraws whole frames rather than
  doing partial terminal updates.
- No mouse input.
- Query editing avoids UTF-8 continuation-byte splits where practical, but full
  grapheme-cluster editing remains deferred.
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

Right-preview composition uses ANSI-aware display width accounting. Highlight
and inverse-video escape sequences are ignored when padding the result pane, so
styled rows still align with the preview border. Terminal itself only exposes
style fragments; width policy remains in `Text_width`.

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

## Debug diagnostics

`OFZF_DEBUG=1` enables lightweight diagnostics for terminal-facing paths. Logs go
to stderr and may include detected terminal rows/columns and the selected preview
layout. Normal stdout output is unchanged. Debug mode is intentionally not a raw
terminal trace and does not print keypress streams or candidate contents.
