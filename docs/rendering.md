# Rendering

`lib/render.ml` owns pure ANSI frame rendering for interactive mode. It consumes
query text, result rows, terminal dimensions, preview layout choices, and an
already-loaded `Preview.content` value. Rendering does not perform filesystem IO.

Responsibilities:

- prompt/status rendering;
- empty-result messages;
- match-position highlighting;
- selected-row inverse styling;
- Unicode/display-width clipping;
- ANSI-aware width measurement for right-preview alignment;
- right and bottom preview composition;
- preview border and title/body line rendering.

The renderer receives loaded preview content from `Preview_state`; it never calls
`Preview.content_for_selection`. This keeps IO in state-update code and makes
frame generation deterministic and unit-testable.

ANSI escape sequences are contained in terminal-facing modules. Core matching,
scoring, search, and cache code remain unaware of UI styling.
