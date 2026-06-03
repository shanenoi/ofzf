# Query Editing

`lib/query_edit.ml` owns pure query editing. It has no terminal raw-mode or
rendering dependency; the interactive loop maps decoded terminal keys to
`Query_edit.action` values and then applies them to query state.

The module supports cursor-aware operations even though the current interactive
path remains append-oriented for backward compatibility:

- printable character insertion;
- Backspace before the cursor;
- Delete at the cursor;
- Ctrl-U clear;
- Ctrl-W delete previous whitespace-delimited word;
- cursor clamping and left/right/start/end movement helpers.

Cursor positions are byte offsets. Helpers clamp to UTF-8 byte boundaries where
practical so editing avoids splitting decoded cells for common UTF-8 input. This
is still not a complete grapheme-aware editor; full Unicode query editing remains
deferred.

`Interactive.apply_key_to_query` is now a compatibility wrapper over
`Query_edit.apply_append_action`, so existing append/backspace behavior remains
unchanged while tests can exercise the lower-level cursor-aware helpers directly.
