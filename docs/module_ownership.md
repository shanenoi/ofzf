# Module ownership

This document defines the intended ownership boundaries after the interactive
module split. Keeping these boundaries clear is the main guardrail before adding
larger features such as multi-select or command-based previews.

| Module | Owns | Must not own |
| --- | --- | --- |
| `Matcher` | Case-insensitive subsequence matching and byte match positions. | ANSI rendering, terminal state, filesystem access. |
| `Scoring` | Numeric relevance scoring and stable ranking order. | Candidate IO, terminal UI. |
| `Topk` | Bounded stable best-K container. | Matching or scoring policy. |
| `Search_engine` | Full/incremental search orchestration and search statistics. | Terminal rendering, raw mode, preview loading. |
| `Query_cache` | Exact/prefix query result reuse and bounded cache memory. | Ranking, terminal UI. |
| `Query_edit` | Pure query text edits. | Terminal raw-mode reads or ANSI rendering. |
| `Selection` | Selected-row movement and preservation. | Terminal IO, candidate loading. |
| `Viewport` | Result-window calculations using actual layout bounds. | ANSI string construction, filesystem IO. |
| `Text_width` | UTF-8-safe display width, clipping, and ANSI-width helpers. | Fuzzy matching or scoring. |
| `Preview` | Preview layout, path classification, file preview loading, and preview content normalization. | Shell execution, placeholder expansion, terminal lifecycle. |
| `Preview_state` | Selected preview candidate, loaded preview content, and scroll offset. | ANSI frame rendering. |
| `Render` | Pure ANSI frame/result/preview rendering from already-loaded state. | Filesystem IO and terminal raw-mode lifecycle. |
| `Terminal` | Raw mode, alternate screen, key parsing, terminal size, ANSI primitives. | Search/ranking policy. |
| `Interactive` | Terminal lifecycle, event loop, state transitions. | Low-level matching/scoring policy or direct preview rendering details. |
| `Cli` | Deterministic argument parsing and validation. | Search execution or terminal IO. |
| `Debug` | Opt-in debug logs to stderr. | Normal stdout output or file-content logging. |

The most important purity boundary is: `Render` consumes already-loaded preview
content and must never call `Preview.content_for_selection` or touch the
filesystem.
## Test ownership

Each major module now has a focused test file under `test/`. Process-level CLI
coverage is in `test/cli_process_test.ml`; the default Dune test workflow builds
the real executable and provides its path through `OFZF_TEST_BIN`. Those smoke
tests still avoid a real interactive TTY and keep parser-only coverage separate
from executable behavior checks.
