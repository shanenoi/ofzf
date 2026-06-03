# Query Cache

`Query_cache` stores previously computed matching candidate subsets by exact
query text. It is intentionally small, bounded, and dependency-free so
interactive search can reuse it while a user types without unbounded memory
growth.

## Exact lookup

An exact cache hit returns the candidate subset for the same query. The search
engine can skip matching and only re-rank the cached subset for the requested
output mode or limit.

```text
query "mat" cached -> later query "mat" reuses cached subset directly
```

## Prefix relationship detection

The cache also detects when a cached query is a prefix of a new query:

```text
m -> ma -> mat -> matc
```

If `mat` extends `ma`, every candidate that can match `mat` must already be in
the candidate subset that matched `ma`. The engine can therefore search inside
that smaller subset instead of the full input.

The cache returns the longest prefix entry so reuse is as selective as possible.
For example, if both `m` and `ma` are cached, query `mat` uses the `ma` subset.

## Memory behavior

Each cached entry stores:

- the query string;
- the matching candidate strings for that query.

This uses more memory than a stateless search, but it lets each additional typed
character narrow a previous result set instead of rescanning all input. The
current implementation uses a safe default maximum entry count of 64. Adding a
new query moves that query to the front and evicts the oldest entries once the
bound is exceeded. A cache with `max_entries = 0` keeps no entries. Future
versions can add candidate IDs to reduce retained string references further.

## Complexity

For `c` cached queries and query length `q`:

- exact lookup is `O(c)` with the current association-list representation;
- longest-prefix lookup is `O(c * q)`;
- adding or replacing an entry is `O(c)` plus trimming to the configured bound.

This is acceptable for the current milestone because interactive typing usually
creates a small number of cached prefixes. A future hash table plus prefix index
can reduce lookup overhead without changing callers.

## Test coverage

`test/query_cache_test.ml` covers exact cache hits, misses, longest-prefix lookup,
oldest-entry eviction, and zero-entry cache behavior.
