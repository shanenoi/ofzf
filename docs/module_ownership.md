# Module ownership

This document defines the intended ownership boundaries after the interactive
module split. Keeping these boundaries clear is the main guardrail for larger
features such as multi-select and command-based previews.

| Module | Owns | Must not own |
| --- | --- | --- |
| `Matcher` | Case-insensitive subsequence matching, byte match positions, and prepared-query matching helpers. | ANSI rendering, terminal state, filesystem access. |
| `Scoring` | Numeric relevance scoring, stable ranking order, and prepared-query scoring helpers. | Candidate IO, terminal UI. |
| `Topk` | Bounded stable best-K heap and sorted finalization. | Matching or scoring policy. |
| `Search_engine` | Full/incremental search orchestration, original input-index preservation, and search statistics. | Terminal rendering, raw mode, preview loading. |
| `Query_cache` | Exact/prefix query result reuse and bounded cache memory. | Ranking, terminal UI. |
| `Query_edit` | Pure query text edits, byte cursor movement, and UTF-8-boundary clamping. | Terminal raw-mode reads or ANSI rendering. |
| `Selection` | Selected-row movement, preservation, and pure multi-select candidate-ID helpers. | Terminal IO, candidate loading. |
| `Viewport` | Result-window calculations using actual layout bounds. | ANSI string construction, filesystem IO. |
| `Text_width` | UTF-8-safe display width, clipping, and ANSI-width helpers. | Fuzzy matching or scoring. |
| `Preview` | Preview layout, path classification, file preview loading, preview content normalization, and future safe command-preview execution policy. | Shell interpolation, placeholder expansion, terminal lifecycle. |
| `Preview_state` | Selected preview candidate, loaded preview content, preview source identity, and scroll offset. | ANSI frame rendering or process-spawn policy. |
| `Render` | Pure ANSI frame/result/preview rendering from already-loaded state, including multi-select candidate-ID markers supplied by `Interactive`. | Filesystem IO, selection mutation, and terminal raw-mode lifecycle. |
| `Terminal` | Raw mode, alternate screen, key parsing, terminal size, ANSI primitives. | Search/ranking policy. |
| `Interactive` | Terminal lifecycle, event loop, cursor/query state transitions, and multi-select state transitions. | Low-level matching/scoring policy or direct preview rendering details. |
| `Cli` | Deterministic argument parsing and validation. | Search execution or terminal IO. |
| `Debug` | Opt-in debug logs to stderr. | Normal stdout output or file-content logging. |

The most important purity boundary is: `Render` consumes already-loaded preview
content and must never call `Preview.content_for_selection` or touch the
filesystem.

For the planned safe command-preview feature, `Preview` should own argv
construction, output limits, timeouts, and conversion into `Preview.content`.
`Render` should still receive only loaded content, and `Terminal`,
`Search_engine`, `Matcher`, `Scoring`, and `Topk` should remain unaware of
preview commands.

## Test ownership

Each major module now has a focused test file under `test/`. Process-level CLI
coverage is in `test/cli_process_test.ml`; the default Dune test workflow builds
the real executable and provides its path through `OFZF_TEST_BIN`. Those smoke
tests still avoid a real interactive TTY and keep parser-only coverage separate
from executable behavior checks.
