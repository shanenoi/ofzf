# Text Width

Terminal rendering cannot safely use OCaml byte length as display width. A byte
is not a terminal column: UTF-8 characters can use multiple bytes, combining
marks can use zero columns, East Asian characters often use two columns, and ANSI
style sequences should not count as visible text at all.

`lib/text_width.ml` provides a small dependency-free width layer for interactive
rendering. It is intentionally not a complete Unicode implementation, but it is
safer than byte-count clipping and is sufficient for real-world filenames in the
current MVP.

## Strategy

The helper decodes input as UTF-8 into display cells. Each cell stores:

- the rendered text fragment;
- byte start and end positions in the original string;
- an estimated terminal display width.

Invalid UTF-8 bytes are represented as the replacement character `�` and consume
one input byte. This keeps rendering deterministic and avoids cutting or
emitting broken byte sequences.

## Width rules

The current rules are conservative:

- ASCII printable characters are width 1;
- tabs use a fixed width of 4 columns;
- control bytes are width 0;
- common combining-mark ranges are width 0;
- common East Asian wide ranges are width 2;
- emoji ranges use a width-2 fallback where practical;
- other valid UTF-8 code points are width 1.

These rules are good enough for safe clipping, not a replacement for a full
`wcwidth` table.

## Clipping

Interactive rows and prompts are clipped by display width, not byte length.
The clipping logic only emits complete decoded cells, so it avoids splitting
inside a UTF-8 sequence where practical. ANSI styling is added after clipping,
so style bytes are never counted as visible columns.

## Highlighting interaction

Matcher positions remain byte indexes. The interactive renderer maps those byte
positions onto decoded text cells. A cell is highlighted if any matched byte
position falls inside that cell. This preserves exact ASCII behavior while
keeping UTF-8 candidates safe to render.

For example, an ASCII query against `a界b` still highlights the ASCII bytes for
`a` and `b`; clipping can hide `b` without corrupting the wide `界` glyph.

## Prompt and cursor columns

Prompt rendering uses `Text_width.prompt_view` to keep the query cursor visible
where practical. The returned cursor column is based on display columns, not
bytes. Long queries are horizontally clipped from the left when the cursor is at
or near the end, so the most relevant editing area remains visible.

The current interactive input path is still byte-oriented, so full Unicode query
editing is future work. Rendering is width-aware; raw input editing is not yet a
complete grapheme-aware editor.

## Limitations

- The width table is approximate.
- Ambiguous-width characters are treated as narrow.
- Complex emoji sequences and zero-width-joiner clusters are not fully modeled.
- Query editing still deletes bytes, not grapheme clusters.
- No external Unicode database is bundled yet.

Future versions can replace the internal width table with a generated `wcwidth`
implementation while preserving the public helper API.

## Preview clipping

Preview content uses the same width-aware clipping helpers as result rows and prompts. This keeps long selected candidates from overflowing the preview pane and avoids cutting inside decoded UTF-8 cells where practical.

Styled result rows use `Text_width.display_width_ansi` when `Render` must measure
already-rendered strings, such as padding the result pane next to a right-side
preview. That helper strips simple CSI ANSI sequences before measuring, so
inverse-video and match-highlight escapes do not count as visible columns.

## File-preview interaction

File preview lines use the same display-width clipping path as interactive
result rows and prompts. The preview loader normalizes CRLF/LF line endings and
passes each line through `Text_width.clip`, so long file lines and Unicode paths
stay within the preview pane without byte-length clipping.
