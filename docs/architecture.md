# Architecture

`ofzf` is a fuzzy finder with two process-level paths: a backward-compatible
non-interactive filter and a small interactive terminal MVP.

```text
stdin line stream + argv query/options
  -> bin/main.ml
  -> Ofzf.Cli.parse
  -> Ofzf.Matcher.match_candidate per line
  -> full sort or Topk heap accumulator
  -> ranked matching lines on stdout

interactive mode:
stdin candidates + no argv query
  -> read candidates once
  -> Terminal raw mode + alternate screen on /dev/tty
  -> Interactive loop
  -> Search_engine.incremental_search on query edits
  -> ANSI-rendered highlighted result window on /dev/tty
  -> optional Preview content loading for selected candidates
  -> selected candidate(s) on stdout

bench mode:
stdin candidates + query
  -> Search_engine.full_search
  -> Search_engine.incremental_search over query prefixes
  -> timing/cache statistics on stdout
```

## Components

For a concise ownership table, see `docs/module_ownership.md`.

### CLI

`bin/main.ml` owns process-level behavior:

- parse no-query interactive mode, `QUERY`, `--limit N QUERY`, or
  `--bench QUERY`;
- read candidate lines from standard input one at a time;
- match and score each line as it arrives;
- keep every match for full ranking, or only the best `N` for limited ranking;
- print only the ranked matching candidate text.

The non-interactive search path intentionally does not know about terminal UI,
raw mode, previews, or selection state. Interactive mode reads all candidates
once, then hands control to `Interactive`.

### Matcher library

`lib/matcher.ml` owns fuzzy matching:

- case-insensitive subsequence matching;
- zero-based byte match positions;
- a stable public `match_result` API;
- prepared-query helpers for repeated matching against many candidates;
- compatibility wrappers around full ranking and top-k ranking.

Matcher does not decide ranking policy. It finds positions and delegates score
calculation to `Scoring`.

### Scoring library

`lib/scoring.ml` owns relevance scoring and stable ordering:

- consecutive-match bonus;
- boundary bonus for path, word, bullet, whitespace, and CamelCase boundaries;
- early-match bonus;
- gap penalty;
- exact-match bonus;
- prefix bonus;
- path-depth penalty;
- candidate-length penalty;
- tie handling by original input order;
- prepared-query scoring helpers so matching and ranking can reuse normalized
  query state without moving scoring policy into callers.

### Top-k library

`lib/topk.ml` maintains a bounded heap of the best results. It keeps the weakest
retained item at the internal heap root, then returns sorted best-first results
at the end. It orders by score descending and then by original input index
ascending. The CLI uses the heap accumulator for `--limit N`, so limited
searches do not retain every matching candidate.

### Query editing

`lib/query_edit.ml` owns pure query editing. It supports insert/delete,
Backspace, Ctrl-U, Ctrl-W, cursor clamping, and cursor movement helpers without
depending on terminal raw mode or rendering. `Interactive` stores the query byte
cursor, maps decoded keys to query-edit actions, reruns search only when text
changes, and asks `Render` to position the terminal cursor in the prompt.

### Selection and viewport

`lib/selection.ml` owns selected-index movement, clamping, selected-candidate
lookup, selection preservation after result changes, and pure multi-select ID
helpers that keep marked candidates in original input order while preserving
duplicate candidate rows. `lib/viewport.ml` owns
prompt/status header sizing, visible-window calculation, and preview-layout-aware
result-pane row counts.

### Query cache

`lib/query_cache.ml` stores matching candidate subsets by query. It supports
exact query lookup and longest-prefix detection so an interactive search can
narrow from prior results when the user extends the query. The cache has a
documented bounded default and deterministic oldest-entry eviction to prevent
unbounded growth in long sessions.

### Search engine

`lib/search_engine.ml` coordinates full and incremental search. Its
`search_context` stores the previous query, previous candidate subset, query
cache, and statistics. Normal CLI search remains streaming; `--bench` and the
benchmark executable use this engine to measure incremental behavior. Search
loops prepare each query once per pass and keep matcher/scoring internals inside
their owning modules.

### CLI parser

`lib/cli.ml` parses process arguments and centralizes usage/error messages. It
keeps command-line behavior testable without spawning a process.

Argument validation is order-independent. Preview is interactive-only, so
`--preview-position` without `--preview`, `--preview --limit`,
`--preview --bench`, `--multi --bench`, and `--multi --limit` are rejected with
clear errors. `--bench --limit N QUERY`
remains valid.

### Benchmark executable

`bench/benchmark.ml` reads candidates from stdin and prints:

- candidate count;
- query length;
- limit;
- matching count;
- matching time;
- full ranking time;
- full-search matching and ranking time;
- incremental matching and ranking time;
- candidate reduction ratio;
- cache hit/miss and reuse counts.

This gives each ranking milestone a simple regression check before terminal UI
exists.

### Terminal library

`lib/terminal.ml` owns low-level terminal behavior without ncurses:

- open `/dev/tty` separately from stdin/stdout;
- save and restore the previous terminal mode;
- enter non-canonical, no-echo raw mode;
- enter and leave the ANSI alternate-screen buffer;
- decode character input, Backspace, Ctrl-U, Ctrl-W, Ctrl-C, Enter, Escape,
  Up/Down arrows, and unknown escape sequences;
- provide ANSI helpers for clearing the screen, cursor movement, cursor
  visibility, inverse-video selection, and matched-character highlighting;
- detect terminal height and width where practical, with safe fallbacks;

Using `/dev/tty` lets stdin remain the candidate stream and stdout remain the
selected result stream.

### Text-width library

`lib/text_width.ml` owns display-width calculations for interactive rendering:

- safe UTF-8 decoding with invalid-byte replacement;
- ASCII and tab width handling;
- zero-width handling for common combining marks;
- double-width handling for common East Asian and emoji ranges;
- width-aware clipping that avoids splitting UTF-8 cells;
- prompt views that keep the cursor-side query text visible where practical.

The matcher still reports byte positions. The interactive renderer maps those
positions onto decoded text cells before adding ANSI highlight sequences, so
ASCII matching behavior remains unchanged while non-ASCII candidates render
safely.

### Rendering

`lib/render.ml` owns pure ANSI frame rendering. It consumes already-loaded
preview content, terminal dimensions, query/result state, and layout decisions.
It performs no filesystem IO and keeps ANSI concerns out of matcher/search code.
Right-side preview alignment uses ANSI-aware width accounting so match
highlighting and selected-row inverse video do not count as visible columns.

### Preview state

`lib/preview_state.ml` owns the selected preview candidate, loaded
`Preview.content`, preview source identity, and preview scroll offset. It
reloads preview content only when the selected candidate or preview source
changes, then clamps scroll against the loaded content.

This split makes preview filesystem access and command execution explicit during
state updates. The rendering path receives `Preview.content` and cannot trigger
additional file loads or process spawns.

### Debugging

`lib/debug.ml` provides opt-in debug logging through `OFZF_DEBUG=1`. Logs go to
stderr so stdout remains reserved for ranked or selected candidates. Debug logs
focus on high-level state such as CLI mode, search/cache statistics, terminal
size/layout, selected-candidate changes, and preview source kind. File contents
and full candidate lists are intentionally never logged.

### Interactive UI

`lib/interactive.ml` now primarily owns terminal setup/restore, alternate-screen
lifecycle, the event loop, and state transitions. It delegates query editing,
selection, viewport math, rendering, and preview state to focused modules. It
uses the existing incremental search engine whenever the query changes, then
renders only the visible result window.

When `--preview` is enabled, the viewport uses the preview-adjusted result-pane
height before selecting visible rows. Preview content is loaded during state
updates, not during frame rendering. Preview scroll state is kept separate from
result selection, resets when the selected candidate changes, and is clamped to
the loaded content bounds.

### Preview library

`lib/preview.ml` owns preview layout, candidate classification, file-content
loading, safe command-preview execution, binary-looking detection, CRLF/LF
normalization, and scroll helpers. File preview reads regular files
synchronously up to a conservative 256 KiB limit. Command preview executes one
configured executable directly, passes the highlighted candidate as one argv
argument, captures bounded stdout/stderr, and never invokes a shell or expands
placeholders. Directories, missing paths, unreadable paths, binary-looking
files, plain-text candidates, and command failures all produce explicit preview
content records for the renderer.

CLI option validation lives in `Cli` and is order-independent. Preview is an
interactive-only feature, so preview flags are rejected with `--bench` and
`--limit`.

## Ranking behavior

Candidates that do not match are removed. Matching candidates are scored and
sorted by descending score. Equal scores preserve the original input order rather
than alphabetizing. This makes the tool predictable in pipelines where upstream
order may matter.

## Complexity analysis

For `m` candidates, total input size `N`, query length `q`, and `k` matches:

- matching is `O(N)`;
- scoring is `O(k * q)`;
- full ranking is `O(k log k)` and stores `O(k)` matched results;
- top-k streaming is `O(k log K)` with a heap accumulator, where `K` is the
  requested result count;
- full CLI memory is `O(k)` retained matches;
- limited CLI memory is `O(K)` retained matches;
- incremental prefix searches scan `O(p)` candidate bytes where `p` is the
  previous matching subset size;
- exact cache hits skip matching and only re-rank cached candidates.
- interactive clipping is `O(r)` in the visible rendered bytes/cells for the
  current prompt and result rows, not in the full result set.

The top-k implementation avoids allocating a full sorted result list when a
caller only needs the best `K` candidates. The heap-backed path keeps the bound
at `O(k log K)` while preserving stable final ordering.

Interactive mode loads candidates into memory once before entering raw mode, so
future keystrokes can use the incremental search engine. Rendering cost is
bounded by the visible terminal rows rather than the total result count. The
renderer clears stale content on each redraw, caps pure render output to the
detected terminal height, and clips prompt/status/result rows to the detected
terminal width where practical.

## Future optimization plan

The architecture leaves room for fzf-style speed improvements:

1. Replace list positions with arrays or reusable buffers on hot paths.
2. Cache normalized candidate metadata in future interactive sessions.
3. Store compact candidate references in the query cache to lower memory
   overhead.
4. Add early bailouts when a candidate cannot beat the top-k threshold.
5. Parallelize scoring across chunks for non-streaming batch use cases.
6. Improve terminal redraw minimality.
7. Cache pre-rendered candidate fragments for large interactive result sets.
8. Extend command preview only after the argv-only, no-shell core has real user
   feedback.

### Preview foundation

`lib/preview.ml` owns pure preview layout calculations and safe preview-content
helpers. Interactive mode can request no preview, right-side preview, or bottom
preview. File preview reads readable regular file contents and falls back to
clear messages/text for other selected candidates. Command preview executes one
configured executable directly with the highlighted candidate as one argv
argument. It deliberately does not execute shell strings or expand placeholders.
Tiny terminals hide preview and keep the result list usable.
