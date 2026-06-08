# Selection and Viewport

Selection and viewport logic live in `lib/selection.ml` and `lib/viewport.ml`.
These modules are pure and do not depend on terminal raw mode, ANSI rendering, or
preview file loading.

`Selection` owns:

- selected-index clamping;
- line and page movement;
- Enter-key selection result helpers;
- selected-candidate lookup;
- preserving the selected candidate after query/result changes when it still
  exists in the new result set.
- pure multi-select helpers for toggling candidate text, keeping marked
  candidates in original input order, and falling back to the highlighted row
  when no candidates are marked.

`Viewport` owns:

- the two-row prompt/status header model;
- result-row capacity calculation;
- visible window start/stop bounds;
- preview-layout-aware result-window sizing.

Preview layout is computed before result-window bounds. This means right and
bottom preview modes use the actual result-pane dimensions, so the selected row
remains visible and bottom preview does not borrow rows from the preview pane.
Tiny terminal dimensions clamp safely to zero or a small number of visible rows
instead of rendering past the screen.
