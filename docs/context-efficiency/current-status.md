# Bmux Context Efficiency: Current Status

Last updated: 2026-07-23

This file is the live handoff index for context-efficiency, provenance, and
handoff work. Keep it concise; move slice history and detailed findings into
topic documents.

## Read Order

1. `AGENTS.md`
2. `docs/context-efficiency/current-status.md`
3. `docs/context-efficiency/roadmap.md`
4. `docs/context-efficiency/milestones.md`
5. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
6. `docs/context-efficiency/provenance-engine-phase3-plan.md`
7. `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
8. `docs/context-efficiency/integration/provenance-engine-adoption.md`
9. Relevant bmux skills for Swift/package/build/test/localization work.

## Active State

The standalone Provenance Engine is the accepted provenance storage/query
boundary. The accepted dependency for bmux adoption is provenance-engine
`0.1.0`, tag/revision `b73fd1639c1c81230e96215259fc796b517706f6`, from
`git@github.com:BrianBusby/provenance-engine.git`.

bmux now consumes provenance-engine as an external Swift package. The Xcode
project links the public products `ProvenanceEngineContracts` and
`ProvenanceEngineSDK`.

The first external query path is complete: `bmux provenance worktrees list`
constructs an in-process SQLite-backed engine client through
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`.

CLI presentation and compatibility remain owned by bmux. The worktree-list JSON
shape, text shape, missing-database behavior, empty-database behavior,
newest-first ordering, and the 25-row text cap were preserved.

The project is now in controlled incremental migration from bmux-local
provenance storage/query code to the external engine. This is a transitional
state, not a target architecture.

## Current Boundary

Externalized work includes the worktree-list read path, engine package pin, public SDK client construction for that path, and worktree-list test seeding through public engine APIs.

Still bmux-local: legacy SQLite schema ownership, event/projection storage used by unmigrated paths, session-tree reads, file-explanation reads, current-context reads, lifecycle/capture recording, observability tracing, presentation, command parsing, fallback messages, and output formatting.

Do not add engine features speculatively. Engine expansion is frozen until a real bmux migration slice proves a concrete missing contract or correctness defect.

## Next Target

Next valid slice: Slice B, legacy boundary clarification.

Slice B should rename the bmux-local provenance client seam so it cannot be confused with the external `ProvenanceEngineClient`, then inventory remaining local provenance consumers by read, write, capture, presentation, and policy.

Do not begin the legacy protocol rename, session-tree migration, file explanation migration, current-context migration, lifecycle writes, data migration, semantic retrieval, daemon transport, UI work, or observability expansion until the appropriate slice is explicitly requested.

## Canonical Details

Migration state and plan: `docs/context-efficiency/integration/provenance-engine-adoption.md`.

Slice history: `docs/context-efficiency/integration/provenance-engine-adoption-history.md`.

Findings template: `docs/context-efficiency/integration/provenance-engine-integration-findings-template.md`.

Durable roadmap: `docs/context-efficiency/roadmap.md`.

Phase 4 migration plan: `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

## Validation Notes

For Slice A documentation reconciliation, validation is documentation and source inspection only. No Swift or CLI behavior changes belong in this slice.

Before handing off Slice A, verify the package pin, external worktree-list runtime path, public-API test seeding, and absence of stale root-level Git exports.
