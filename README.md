# ProvenanceEngine

ProvenanceEngine is the independent local-first provenance product. This repository currently contains the initial contract module and the first internal storage support module.

## Package

- Package: `ProvenanceEngine`
- Public contract module: `ProvenanceEngineContracts`
- Internal storage module: `ProvenanceEngineSQLite`
- Language mode: Swift 6
- Scope: Foundation-only contracts plus engine-owned SQLite storage location, connection, statement, migration, repository-opening, internal event-ledger support, bounded append-order ledger cursor reads, session/worktree tree projections, and initial file-explanation projection storage

The first public module is intentionally narrow. It does not include bmux imports, AppKit, SwiftUI, daemon or IPC transport, launch agents, CLI surfaces, storage migration from bmux, retrieval, lifecycle policy, UI, or observability.

New engine-owned data defaults to `~/.local/state/provenance-engine/provenance.sqlite`, but this package does not move or migrate existing bmux storage.

`ProvenanceEngineSQLite` remains an internal package target, not a public library product. Its repository actor currently bootstraps the first engine-owned `provenance_events` table plus current-state projections for sessions, repositories, worktrees, session relationships, external identities, work items, contributions, checkpoints, change sets, file changes, and validation runs. It can open the engine-owned default storage location internally, read bounded event-ledger entries by append sequence for future internal replay/rebuild work, and satisfies the in-process `ProvenanceEngineClient` contract over the SQLite append, lifecycle recording, worktree list, session tree, file explanation, current context, and health paths.
