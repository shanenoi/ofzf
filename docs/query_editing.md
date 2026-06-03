# Query Editing

Interactive query editing is deliberately small and dependency-free. The current
editing model is append-oriented with byte-level Backspace, Ctrl-U to clear the
query, and Ctrl-W to delete the previous whitespace-delimited word.

## Current keys

| Key | Behavior |
| --- | --- |
| Printable byte | Append to the query |
| Backspace | Delete one byte before the end of the query |
| Ctrl-U | Clear the full query |
| Ctrl-W | Delete the previous whitespace-delimited word |
| Escape | Cancel interactive mode |
| Ctrl-C | Cancel interactive mode |
| Enter | Print the selected result, or exit non-zero when no result exists |

Every query edit runs through `Search_engine.incremental_search`, so prefix
searches can reuse previous candidate subsets.

## Width-aware prompt rendering

Even though the editing model is byte-oriented, prompt rendering is now display
width-aware. Long queries are clipped by terminal columns rather than bytes, and
UTF-8 text is decoded safely before rendering. The prompt helper keeps the
cursor-side portion of the query visible where practical.

## Limitations

- There is no mid-query cursor editing yet in this applied source line.
- Backspace and Ctrl-W are byte/string helpers, not grapheme-cluster operations.
- Invalid UTF-8 in input is rendered safely, but raw input parsing is still
  byte-oriented.

Future navigation polish can add left/right cursor movement, Delete, Home/End,
Page Up/Page Down, and grapheme-aware editing on top of the text-width helpers.

## Preview interaction

Query editing behavior is unchanged when preview is enabled. Each query edit recomputes results through the search engine, clamps selection, and refreshes the preview pane from the selected candidate.
