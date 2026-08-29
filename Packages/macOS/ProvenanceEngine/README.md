# ProvenanceEngine

ProvenanceEngine is the independent local-first provenance package inside the
bmux monorepo. The implemented platform provides public contracts, a public
in-process SDK, engine-owned SQLite storage, an immutable ledger, deterministic
Current State, factual session projections, semantic inference records, semantic
messages, SessionWorkModel, related-session awareness, and adopted bmux
integration through the public SDK.

The monorepo removes cross-repository coordination overhead; it does not make PE
a bmux implementation detail. PE must not import bmux app, runtime, terminal, or
UI internals.

## Planning

- Platform reference architecture: `docs/reference-architecture.md`
- Documentation authority index: `docs/README.md`
- Monorepo architecture index: `../../../docs/architecture/README.md`
- Generated project status: `../../../docs/generated/project-status.md`
- Current implemented architecture: `docs/architecture.md`
- Product roadmap and implementation sequence: `docs/roadmap.md`
- Technical integration contract: `docs/integration-contract.md`
- Turn Outcome factual projection contract: `docs/turn-outcome.md`
- Related-session awareness contract: `docs/related-sessions.md`
- Canonical bmux integration roadmap: `docs/bmux-integration-roadmap.md`
- Historical current-status baseline: `docs/current-status.md`
- Historical Slice D file-explanation readiness evidence: `docs/file-explanation-readiness-slice-completion.md`
- Historical Slice E current-context readiness evidence: `docs/current-context-readiness-slice-completion.md`
- V1 write-side validation evidence: `docs/write-side-validation-milestone.md`
- Canonical V1 platform boundary: `docs/v1-boundary-review.md`

## Package

- Package: `ProvenanceEngine`
- Public contract module: `ProvenanceEngineContracts`
- Public in-process SDK module: `ProvenanceEngineSDK`
- Internal storage module: `ProvenanceEngineSQLite`
- Language mode: Swift 6
- Scope: Foundation-only contracts, optional event evidence-origin and evidence-scope metadata, public factory construction for SQLite-backed in-process clients, engine-owned SQLite storage location, connection, statement, migration, repository-opening, schema identity validation, internal schema-migration metadata, internal event-ledger support, durable accepted local SDK writes, bounded append-order ledger cursor reads, internal event-ledger validation, internal projection-count/key validation and repair, internal storage summary, integrity reports, gated repair attempts, bounded repair-attempt metadata, internal projection rebuild from ledger replay, session/worktree tree projections, file-explanation projection storage, current-context projection reads, and producer-neutral lifecycle recording

The public modules are intentionally narrow. They do not include bmux imports, AppKit, SwiftUI, daemon or IPC transport, launch agents, CLI surfaces, storage migration from bmux, retrieval, lifecycle policy, UI, or observability.

New engine-owned data defaults to `~/.local/state/provenance-engine/provenance.sqlite`, but this package does not move or migrate existing bmux storage.

`ProvenanceEngineSDK` exposes `ProvenanceEngineClientFactory` for creating a SQLite-backed `any ProvenanceEngineClient` at either an explicit database URL or the engine-owned default storage path.

`ProvenanceEngineSQLite` remains an internal package target, not a public library product. Its repository actor currently bootstraps the first engine-owned `provenance_events` table plus optional event evidence-origin/scope metadata and current-state projections for sessions, repositories, worktrees, session relationships, external identities, work items, contributions, checkpoints, change sets, file changes, and validation runs. It also owns internal schema-migration and storage-repair attempt metadata. It can open the engine-owned default storage location internally, read bounded event-ledger entries by append sequence, read bounded newest-first schema-migration records, validate bounded ledger rows through the same decoder used by ledger reads, compare current projection counts and projection keys against complete bounded ledger replay, repair detected projection-key drift by replaying the immutable ledger when validation is complete, summarize internal ledger/projection row counts, classify bounded storage integrity as healthy, invalid-ledger, projection-drift, or truncated-validation state, gate storage-integrity repair attempts through complete bounded validation, persist bounded metadata for completed storage-repair wrapper calls, rebuild current-state projection tables by replaying the immutable ledger in append order, and satisfies the in-process `ProvenanceEngineClient` contract over the SQLite append, producer-neutral lifecycle recording, worktree list, session tree, file explanation, current context, and health paths.
