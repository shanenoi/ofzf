# Preview State

`lib/preview_state.ml` owns the currently selected candidate, loaded preview
content, and preview scroll offset.

The state update path is:

```text
selected candidate changes
  -> Preview_state.update
  -> Preview.content_for_selection
  -> scroll reset to 0
```

If the selected candidate is unchanged, preview state is reused and no preview
loader call is made. This prevents repeated `stat`/open/read work during redraws
and scroll-key handling.

Preview state also owns scroll clamping and scroll-key deltas. The scroll offset
is clamped against the already-loaded line count and visible preview rows. The
256 KiB preview read cap remains in `Preview`; `Preview_state` only decides when
that loader is invoked.
