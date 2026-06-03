# Preview Window

`ofzf` v0.11 adds the first preview-window foundation for interactive mode.
The preview is intentionally simple and synchronous: it shows the currently
selected candidate text. It does not execute external commands, expand shell
syntax, or interpret `{}` placeholders yet.

## CLI options

```sh
ofzf --preview
ofzf --preview QUERY
ofzf --preview --preview-position right QUERY
ofzf --preview --preview-position bottom QUERY
```

`--preview-position` accepts `right` or `bottom`. Invalid values fail before
interactive mode starts. Existing non-preview modes remain unchanged.

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
lines stable at the top.

## Rendering strategy

The interactive renderer keeps ANSI styling local to terminal/UI code. Result
rows still use matcher positions for highlighting. Preview content uses
`Text_width` clipping, so long candidate text is clipped by terminal display
columns rather than bytes.

The current preview pane renders a small border where practical, a status/title
line, and the selected candidate text. If no result is selected, it shows a
helpful empty-preview message.

## Why commands are not executed yet

Command-based previews are useful but security-sensitive. v0.11 intentionally
avoids shell execution, placeholder expansion, and arbitrary command strings.
This gives the project a tested layout and rendering foundation before adding a
controlled command model in a later milestone.

## Limitations

- Preview content is the selected candidate text only.
- No async preview execution.
- No background workers.
- No shell integration or placeholder expansion.
- No multi-select interaction with preview yet.
