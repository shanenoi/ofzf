# Preview Window

`ofzf` v0.12 extends the preview-window foundation with safe file-content
preview and preview scrolling. The preview is intentionally synchronous and
does not execute external commands, expand shell syntax, or interpret `{}`
placeholders yet.

## CLI options

```sh
ofzf --preview
ofzf --preview QUERY
ofzf --preview --preview-position right QUERY
ofzf --preview --preview-position bottom QUERY
```

`--preview-position` accepts `right` or `bottom`. Invalid values fail before
interactive mode starts. `--preview-position` without `--preview` is rejected,
as are `--preview --bench` and `--preview --limit N`, because preview mode is an
interactive UI path and those modes are non-interactive. Existing non-preview
modes remain unchanged, including `--bench --limit N QUERY`.

## Layout model

`lib/preview.ml` contains pure helpers that compute the result and preview
rectangles from terminal rows and columns. The layout supports:

- no preview;
- right-side preview;
- bottom preview;
- minimum result-list dimensions;
- minimum preview dimensions;
- tiny-terminal fallback that hides preview rather than corrupting the UI.

Right preview splits columns between results and preview. Bottom preview keeps
full width and allocates lower rows to preview. Both leave the prompt and status
lines stable at the top. The interactive renderer computes this layout before
calculating the result-list viewport, then uses the actual result-pane rows to
keep the selected row visible.

## Content source

The selected candidate is classified before rendering:

- readable regular file: preview up to 256 KiB of file contents;
- directory: show a directory message;
- missing path: show a missing-path message;
- unreadable path: show an unreadable-file message;
- binary-looking file: omit raw bytes and show a binary message;
- plain text: show the candidate text itself.

Preview is file-read only. It does not invoke a shell, execute selected
candidates, expand placeholders, or run user-provided preview commands.
Symlinks follow the platform's normal `stat` behavior, so a readable symlink
target may be previewed. Debug logs may include preview source kind and reload
events, but they must not include preview file contents.

The missing-path vs plain-text decision uses a conservative path heuristic. A
nonexistent value with path separators, dots, or common relative/home prefixes is
reported as a missing path; other values fall back to plain text preview.

## Rendering strategy

The interactive renderer keeps ANSI styling local to terminal/UI code. Result
rows still use matcher positions for highlighting. Preview content uses
`Text_width` clipping, so long candidate text is clipped by terminal display
columns rather than bytes.

Preview file loading is not part of frame rendering. The interactive state keeps
the currently selected candidate, loaded `Preview.content`, and scroll offset.
Content is reloaded only when the selected candidate changes; scroll is clamped
against the already-loaded content.

Technical Debt Pass 2 moved this ownership into `Preview_state` and moved frame
composition into `Render`. `Preview` still owns filesystem classification and
safe content loading; `Preview_state` decides when to call it; `Render` receives
plain content data and performs no file IO.

The current preview pane renders a small border where practical, a status/title
line, and clipped preview lines. If no result is selected, it shows a helpful
empty-preview message. Preview lines use `Text_width` clipping, so long Unicode
text does not split UTF-8 cells where practical.

## Scrolling

Preview scroll state is independent from result selection. It resets when the
selected candidate changes or when a query recomputation changes the selected
candidate. The scroll offset is clamped to valid content bounds.

| Key | Action |
| --- | --- |
| Alt-Up or Ctrl-Y | preview line up |
| Alt-Down or Ctrl-E | preview line down |
| Ctrl-B | preview page up |
| Ctrl-F | preview page down |

Page Up and Page Down remain result-list navigation keys.

## Why commands are not executed yet

Command-based previews are useful but security-sensitive. The current preview path intentionally
avoids shell execution, placeholder expansion, and arbitrary command strings.
This gives the project a tested layout and rendering foundation before adding a
controlled command model in a later milestone.

## Limitations

- Preview reads at most 256 KiB from a selected file.
- Preview loading is synchronous.
- Binary detection is heuristic.
- No async preview execution.
- No background workers.
- No shell integration or placeholder expansion.
- No multi-select interaction with preview yet.

The current Top-K implementation remains a bounded sorted list. It is stable and
simple for small `K`, while a heap-based implementation remains future work for
large limits.
