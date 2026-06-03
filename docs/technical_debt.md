# Technical Debt Notes

Technical Debt Pass 2 split the former interactive god module into smaller pure
modules and added the foundation for later performance work.

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

Deferred work:

- heap-based Top-K for large `K`;
- ioctl-based terminal size detection instead of `stty`;
- signal-driven resize handling;
- process-level Dune/CLI integration tests;
- full grapheme-aware query editing;
- command-based preview with a safe command model.
