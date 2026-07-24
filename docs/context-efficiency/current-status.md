# Bmux Context Efficiency: Current Status

Last updated: 2026-07-23

This file is the live handoff index for context-efficiency, provenance, and
handoff work. Keep it concise; move slice history and detailed findings into
topic documents.

## Read Order

1. `AGENTS.md`
2. `docs/roadmap.md`
3. `docs/provenance-integration.md`
4. `docs/context-efficiency/current-status.md`
5. `docs/context-efficiency/roadmap.md`
6. `docs/context-efficiency/milestones.md`
7. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
8. `docs/context-efficiency/provenance-engine-phase3-plan.md`
9. `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
10. `docs/context-efficiency/integration/provenance-engine-adoption.md`
11. Relevant bmux skills for Swift/package/build/test/localization work.

## Active State

The standalone Provenance Engine is the accepted provenance storage/query
boundary. bmux adoption currently pins provenance-engine revision
`dbdc4b7e8b33bc0dc9c160d0f23501d2062e213e`, from
`git@github.com:BrianBusby/provenance-engine.git`, because Slice C readiness is
not yet released as a versioned tag.

bmux now consumes provenance-engine as an external Swift package. The Xcode
project links the public products `ProvenanceEngineContracts` and
`ProvenanceEngineSDK`.

The first external query path is complete: `bmux provenance worktrees list`
constructs an in-process SQLite-backed engine client through
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`.

The second external query path is complete in bmux: `bmux provenance sessions
tree <session-id>` constructs an in-process SQLite-backed engine client through
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls
`ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(...))`.

CLI presentation and compatibility remain owned by bmux. The worktree-list JSON
shape, text shape, missing-database behavior, empty-database behavior,
newest-first ordering, and the 25-row text cap were preserved.

The project is now in controlled incremental migration from bmux-local
provenance storage/query code to the external engine. This is a transitional
state, not a target architecture.

## Current Boundary

Externalized work includes the worktree-list read path, the session-tree read path, engine package pin, public SDK client construction for those paths, and session-tree test seeding through public engine APIs.

Slice B clarified the legacy boundary: the bmux-local contract-shaped seam is now `BmuxLegacyProvenanceClient`, while the external `ProvenanceEngineContracts.ProvenanceEngineClient` remains untouched. The complete remaining consumer inventory lives in `docs/context-efficiency/integration/provenance-engine-adoption.md`.

Still bmux-local: legacy SQLite schema ownership, event/projection storage used by unmigrated paths, file-explanation reads, current-context reads, lifecycle/capture recording, observability tracing, presentation, command parsing, fallback messages, and output formatting.

Do not add engine features speculatively. Engine expansion is frozen until a real bmux migration slice proves a concrete missing contract or correctness defect.

## Next Target

Next valid slice after Slice C acceptance: file-explanation read migration.

Slice C migrated only `bmux provenance sessions tree <session-id>` to the external SQLite-backed engine client and `ProvenanceEngineClient.sessionTree(...)`; preserved existing CLI compatibility; seeded tests through public engine APIs; and removed only session-tree legacy code that became unused.

Do not begin current-context migration, lifecycle writes, capture migration, data migration, semantic retrieval, daemon transport, UI work, observability expansion, or unrelated refactoring.

## Canonical Details

bmux product roadmap: `docs/roadmap.md`.

bmux-local provenance integration notes: `docs/provenance-integration.md`.

Canonical shared integration roadmap: `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

Migration state and plan: `docs/context-efficiency/integration/provenance-engine-adoption.md`.

Slice history: `docs/context-efficiency/integration/provenance-engine-adoption-history.md`.

Findings template: `docs/context-efficiency/integration/provenance-engine-integration-findings-template.md`.

Durable roadmap: `docs/context-efficiency/roadmap.md`.

Phase 4 migration plan: `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

## Validation Notes

For Slice C, validation must prove the session-tree command reads through the public engine SDK while preserving bmux presentation: run focused CLI JSON/text/missing-database/no-session/limit coverage, affected WorkProvenance and subsession tests, dependency/package checks, prohibited import/table scans, `git diff --check`, and a tagged Debug reload build.
