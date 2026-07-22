# ProvenanceEngine

ProvenanceEngine is the independent local-first provenance product. This repository currently contains the initial contract module and the first internal storage support module.

## Package

- Package: `ProvenanceEngine`
- Public contract module: `ProvenanceEngineContracts`
- Internal storage module: `ProvenanceEngineSQLite`
- Language mode: Swift 6
- Scope: Foundation-only contracts plus engine-owned SQLite storage location, connection, statement, migration, repository-opening, internal schema-migration metadata, internal event-ledger support, bounded append-order ledger cursor reads, internal event-ledger validation, internal projection-count/key validation and repair, internal storage summary, integrity reports, gated repair attempts, bounded repair-attempt metadata, internal projection rebuild from ledger replay, session/worktree tree projections, and initial file-explanation projection storage

The first public module is intentionally narrow. It does not include bmux imports, AppKit, SwiftUI, daemon or IPC transport, launch agents, CLI surfaces, storage migration from bmux, retrieval, lifecycle policy, UI, or observability.

New engine-owned data defaults to `~/.local/state/provenance-engine/provenance.sqlite`, but this package does not move or migrate existing bmux storage.

`ProvenanceEngineSQLite` remains an internal package target, not a public library product. Its repository actor currently bootstraps the first engine-owned `provenance_events` table plus current-state projections for sessions, repositories, worktrees, session relationships, external identities, work items, contributions, checkpoints, change sets, file changes, and validation runs. It also owns internal schema-migration and storage-repair attempt metadata. It can open the engine-owned default storage location internally, read bounded event-ledger entries by append sequence, read bounded newest-first schema-migration records, validate bounded ledger rows through the same decoder used by ledger reads, compare current projection counts and projection keys against complete bounded ledger replay, repair detected projection-key drift by replaying the immutable ledger when validation is complete, summarize internal ledger/projection row counts, classify bounded storage integrity as healthy, invalid-ledger, projection-drift, or truncated-validation state, gate storage-integrity repair attempts through complete bounded validation, persist bounded metadata for completed storage-repair wrapper calls, rebuild current-state projection tables by replaying the immutable ledger in append order, and satisfies the in-process `ProvenanceEngineClient` contract over the SQLite append, lifecycle recording, worktree list, session tree, file explanation, current context, and health paths.
