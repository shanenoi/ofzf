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
4. restore the saved terminal attributes;
5. close the `/dev/tty` file descriptor.

`Terminal.restore` is idempotent, so repeated cleanup attempts are safe.

## Key event handling

Raw key input is byte-oriented. The current MVP decodes:

- printable character bytes as `Character c`;
- `\r` and `\n` as Enter;
- `\b` and DEL as Backspace;
- Ctrl-C as `Ctrl_c`;
- bare Escape as `Escape`;
- `ESC [ A` as Arrow Up;
- `ESC [ B` as Arrow Down.

Escape sequences are read with a short timeout after the initial Escape byte so
a plain Escape key can still be recognized.

## ANSI rendering helpers

The module exposes helpers for:

- clear screen;
- move cursor;
- hide cursor;
- show cursor.

Rendering remains intentionally simple in v0.6. Higher-level UI state belongs
in `Interactive`, not in `Terminal`.

## Terminal size

Height detection first checks the `LINES` environment variable, then tries a
best-effort `stty size < /dev/tty`. If neither works, the fallback height is 20
rows. This keeps the MVP usable in constrained environments.

## Limitations

- No resize-event handling yet.
- No mouse input.
- No alternate-screen buffer.
- No UTF-8-aware editing; Backspace removes one byte.
- No async input or background indexing.