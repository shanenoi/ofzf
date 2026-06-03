# Query Cache

`Query_cache` stores previously computed matching candidate subsets by exact
query text. It is intentionally small and dependency-free so a future terminal UI
can reuse it while a user types.

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

This uses more memory than a stateless search, but it prepares the core for a
future interactive loop where each additional typed character should narrow a
previous result set instead of rescanning all input. The current implementation
keeps the API simple; future versions can add an eviction policy or candidate
IDs to reduce retained string references.

## Complexity

For `c` cached queries and query length `q`:

- exact lookup is `O(c)` with the current association-list representation;
- longest-prefix lookup is `O(c * q)`;
- adding or replacing an entry is `O(c)`.

This is acceptable for the current milestone because interactive typing usually
creates a small number of cached prefixes. A future hash table plus prefix index
can reduce lookup overhead without changing callers.
