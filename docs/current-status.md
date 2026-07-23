# Provenance Engine Current Status

This document records the accepted baseline and active integration gate. The complete platform north star is `docs/reference-architecture.md`; the currently implemented architecture and active design boundaries are in `docs/architecture.md`.

Accepted baseline: `0.1.0`.

Source baseline: `provenance-session-tree-storage` through commit `b43146d634f7c11f8e14bf95da5418bef502b0de`.

The accepted engine is an independent Swift package with three modules:

- `ProvenanceEngineContracts`
- `ProvenanceEngineSDK`
- `ProvenanceEngineSQLite`

The supported client entrypoint is `ProvenanceEngineClientFactory`, which creates an in-process SQLite-backed `any ProvenanceEngineClient`. The current storage backend owns SQLite schema creation, event ledger persistence, worktree/session/file/current-context projections, validation summaries, and repair reports.

The first bmux adoption path, `bmux provenance worktrees list`, now consumes this package through `ProvenanceEngineClientFactory` and `ProvenanceEngineClient.worktrees(...)`.

Current integration gate: keep V1 adoption narrow. The next coordinated bmux milestone is the session-tree read migration described in `docs/bmux-integration-roadmap.md`. Provenance Engine should not add storage, daemon, migration, retrieval, semantic, observability, GitHub ingestion, or Knowledge Compiler implementation unless that migration proves a concrete public-contract defect.

Long-term architecture note: shared repository evidence and Knowledge Compiler work are accepted as post-V1 planning targets only. The current package preserves optional event evidence-origin and evidence-scope metadata, but GitHub ingestion, shared evidence-store deployment, retrieval, and compiler implementation remain frozen until after the current V1 bmux adoption sequence.

Required verification for this baseline:

```bash
swift test --package-path /Users/brianbusby/repos/provenance-engine
```

Last local verification before acceptance: 69 tests passed on macOS.
