# Preview File Content

`ofzf` v0.12 makes the preview pane useful for file-search workflows without
adding shell execution. The selected candidate is treated as data, not as a
command.

## Source classification

Preview loading classifies the selected candidate before rendering:

- readable regular file: preview the file contents;
- directory: show a directory message;
- missing path: show a missing-file message;
- unreadable path: show an unreadable-file message;
- plain text: show the candidate text itself;
- binary-looking file: omit raw bytes and show a binary-content message.

Missing-path detection uses a conservative path heuristic. Candidates containing
path separators, dots, or common relative/home prefixes are treated as paths when
they do not exist. Other missing values fall back to plain text preview.

## Safety limits

The preview reader reads at most 256 KiB from a regular file. This keeps the
interactive loop synchronous and dependency-free without accidentally slurping a
large file into memory. If the file is larger than the limit, preview content is
truncated and the preview status can show the visible range within the loaded
lines.

Binary detection is best-effort. Files containing NUL bytes or many unusual
control bytes are considered binary-looking and are not rendered as text.

## Line handling

Preview content normalizes CRLF and LF line endings into a list of lines. Long
lines are clipped with `Text_width`, so wide Unicode characters are handled by
display columns and clipping avoids splitting UTF-8 cells where practical.

## Scrolling

Preview scroll state is separate from result-list selection. The current
bindings are:

| Key | Action |
| --- | --- |
| Alt-Up or Ctrl-Y | preview line up |
| Alt-Down or Ctrl-E | preview line down |
| Ctrl-B | preview page up |
| Ctrl-F | preview page down |

Page Up and Page Down remain result-list navigation keys. Preview scroll resets
when the selected candidate changes or when the query is recomputed.

## Command preview boundary

Preview commands are powerful but security-sensitive. The command-preview path
is separate from this file-content path and uses the explicit argv-only model in
`docs/command_preview.md`. It still does not run arbitrary shell strings,
expand `{}` placeholders, or invoke the shell.

## Limitations

- Preview loading is synchronous.
- Only the first 256 KiB of a file is read.
- Binary detection is heuristic.
- No async workers or cancellation yet.
- No shell integration, fixed preview-command arguments, or placeholder
  expansion.
