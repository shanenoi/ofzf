# Technical Debt Notes

Technical Debt Pass 3 keeps the Pass 2 module split, reorganizes tests by module
ownership, adds process-level CLI smoke tests, and introduces minimal debug
logging for future troubleshooting. v0.14 promotes that process-level coverage
into the default Dune test workflow. v0.15 keeps ranking behavior stable while
reducing repeated query/candidate normalization on the search hot path. v0.16
replaces the streaming Top-K bounded-list path with a heap-backed accumulator for
large-limit performance.

Completed in this pass:

- query editing moved to `Query_edit`;
- selection movement moved to `Selection`;
- result-window math moved to `Viewport`;
- ANSI frame rendering moved to `Render`;
- preview content/scroll state moved to `Preview_state`;
- `Interactive` now primarily owns terminal lifecycle and the event loop;
- search no longer matches once for filtering and again for ranking in the
  search-engine path;
- `Query_cache` now has deterministic bounded growth.
- tests are split by ownership: matcher, scoring, top-k, CLI, text width,
  preview, interactive helpers, rendering, query editing, selection, viewport,
  preview state, search engine, and query cache;
- `cli_process_test` exercises the real compiled binary by default through Dune;
- matcher/scoring now expose prepared-query helpers for hot loops without moving
  ranking policy into CLI or interactive code;
- matching avoids lowercase candidate-string allocation and rejects candidates
  shorter than the query before scanning;
- top-k selection now uses a heap accumulator while preserving final best-first
  ordering and stable tie behavior;
- small preview fixtures cover Unicode names, long names, CRLF, binary-looking
  content, directories, and missing paths;
- `OFZF_DEBUG=1` writes concise diagnostics to stderr without changing stdout.

Deferred work:

- full grapheme-aware query editing;
- command-based preview with a safe command model.

Recommended next cleanup order:

1. add command-preview design docs before implementing any shell-facing feature;
2. revisit query editing with full grapheme-cluster behavior;
3. consider top-k threshold bailouts after collecting real-world benchmark data.
