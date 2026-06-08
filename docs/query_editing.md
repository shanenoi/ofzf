# Query Editing

`lib/query_edit.ml` owns pure query editing. It has no terminal raw-mode or
rendering dependency; the interactive loop maps decoded terminal keys to
`Query_edit.action` values and then applies them to query state.

The module supports the cursor-aware operations used by interactive mode:

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

`Interactive` keeps the cursor in its UI state, maps decoded terminal keys to
`Query_edit` actions, and reruns search only when the query text changes. The
older `Interactive.apply_key_to_query` helper remains as an append-mode
compatibility wrapper for tests and callers that only need the final query text.
