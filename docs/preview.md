# Preview Window

`ofzf` supports safe file-content preview, preview scrolling, and a conservative
command-preview mode. Command preview is intentionally synchronous and argv-only:
it does not use a shell, expand shell syntax, or interpret `{}` placeholders.

## CLI options

```sh
ofzf --preview
ofzf --preview QUERY
ofzf --preview --preview-position right QUERY
ofzf --preview --preview-position bottom QUERY
ofzf --preview-command cat QUERY
ofzf --preview-command cat --preview-position bottom QUERY
```

`--preview-position` accepts `right` or `bottom`. Invalid values fail before
interactive mode starts. `--preview-command COMMAND` implies `--preview`, so
`--preview-position` is valid with either flag. Preview and command-preview
forms are rejected with `--bench` and `--limit N`, because preview mode is an
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

File preview does not invoke a shell, execute selected candidates, expand
placeholders, or run user-provided preview commands. Symlinks follow the
platform's normal `stat` behavior, so a readable symlink target may be
previewed. Debug logs may include preview source kind and reload events, but
they must not include preview file contents.

The missing-path vs plain-text decision uses a conservative path heuristic. A
nonexistent value with path separators, dots, or common relative/home prefixes is
reported as a missing path; other values fall back to plain text preview.

## Rendering strategy

The interactive renderer keeps ANSI styling local to terminal/UI code. Result
rows still use matcher positions for highlighting. Preview content uses
`Text_width` clipping, so long candidate text is clipped by terminal display
columns rather than bytes.

Preview loading is not part of frame rendering. The interactive state keeps the
currently selected candidate, preview source, loaded `Preview.content`, and
scroll offset. Content is reloaded only when the selected candidate or source
changes; scroll is clamped against the already-loaded content.

Technical Debt Pass 2 moved this ownership into `Preview_state` and moved frame
composition into `Render`. `Preview` owns filesystem classification, safe
content loading, and command-preview execution policy; `Preview_state` decides
when to call it; `Render` receives plain content data and performs no file IO or
process spawning.

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

## Command preview

Command-based previews are useful but security-sensitive, so v0.20 implements
only the minimal argv model from `docs/command_preview.md`:

```text
executable = COMMAND
argv = [COMMAND; selected_candidate]
```

The command value must be a single executable name or path without whitespace.
`--preview-command "cat -n"`, shell snippets, and `{}` interpolation are
rejected or unsupported. Command stdout/stderr is captured and converted into
`Preview.content`; it is never written to process stdout, which remains reserved
for final selected candidates.

If the command exits successfully, stdout is shown. If stdout is empty but
stderr exists, stderr is shown with a clear preview label. Empty output,
non-zero exits, missing commands, output truncation, and timeout are rendered as
safe preview-pane messages. The highlighted candidate is passed even when it is
an empty string. In `--multi` mode, command preview still follows only the
highlighted row, not every marked row.

## Limitations

- Preview reads at most 256 KiB from a selected file.
- Preview loading is synchronous.
- Command preview uses the same 256 KiB capture cap and a short synchronous
  timeout.
- Binary detection is heuristic.
- No async preview execution.
- No background workers.
- No shell integration, fixed command arguments, complex quoting language, or
  placeholder expansion.
- Preview can be combined with multi-select. The preview pane follows the
  highlighted row; marked candidates are still printed on Enter in input order.

Top-K selection is heap-backed, stable, and bounded to `O(K)` retained results.
Preview rendering consumes already-ranked results and does not depend on the
heap internals.
