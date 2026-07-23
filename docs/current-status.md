# Provenance Engine Current Status

Accepted baseline: `0.1.0`.

Source baseline: `provenance-session-tree-storage` through commit `b43146d634f7c11f8e14bf95da5418bef502b0de`.

The accepted engine is an independent Swift package with three modules:

- `ProvenanceEngineContracts`
- `ProvenanceEngineSDK`
- `ProvenanceEngineSQLite`

The supported client entrypoint is `ProvenanceEngineClientFactory`, which creates an in-process SQLite-backed `any ProvenanceEngineClient`. The current storage backend owns SQLite schema creation, event ledger persistence, worktree/session/file/current-context projections, validation summaries, and repair reports.

Completion gate for the next slice: do not add storage, daemon, migration, retrieval, semantic, or observability features until one real bmux path consumes this package through `ProvenanceEngineClientFactory`.

Long-term architecture note: shared repository evidence and Knowledge Compiler work are accepted as post-V1 planning targets only. The current package now preserves optional event evidence-origin and evidence-scope metadata, but GitHub ingestion, shared evidence-store deployment, retrieval, and compiler implementation remain frozen until after the current bmux adoption gate.

Required verification for this baseline:

```bash
swift test --package-path /Users/brianbusby/repos/provenance-engine
```

Last local verification before acceptance: 69 tests passed on macOS.
