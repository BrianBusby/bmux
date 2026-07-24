# Provenance Engine Extraction: Phase 4 Reconnect Plan

Status: active controlled migration; updated on 2026-07-23 after the second
external bmux adoption slice completed in bmux.

Planning authority: this document is detailed bmux-side Phase 4 history and implementation guidance. The canonical cross-repository bmux to provenance-engine roadmap is `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

Inputs:

- ADR-001 provenance extraction record.
- Phase 1 contract plan.
- Phase 3 plan.
- Semantic roadmap.
- Engine release `0.1.0` at commit
  b73fd1639c1c81230e96215259fc796b517706f6.
- bmux worktree adoption commit 1de39b21438a3257bfb6871cd21e4f187681e518.

## Purpose

Phase 4 reconnects bmux to the independent Provenance Engine after the
contracts and internal engine-owned SQLite implementation exist outside bmux.

This document now tracks the controlled incremental migration from bmux-local
provenance reads to the standalone Provenance Engine.

The first two adapter paths are complete in bmux. Future implementation must
stay scoped to one migration path at a time until each slice is verified and
documented.

## First Adapter Path Complete

The read path behind `bmux provenance worktrees list` has been replaced with
the external engine client.

Reasons:

- It is the narrowest existing Phase 2 CLI conversion.
- It is query-only.
- It does not need Git target resolution or repository-relative file mapping.
- It does not touch session-tree recursion or observability trace reads.
- It already calls the contract-shaped ProvenanceEngineClient.worktrees seam in
  bmux.
- Existing CLI coverage protects JSON shape, text shape, missing database
  behavior, empty database behavior, newest-first ordering, and the text cap.

The completed first slice did not replace provenance explain, provenance
context current, provenance sessions tree, lifecycle recording, observability
traces, capture adapters, storage defaults, or migration paths.

## Engine Version Consumed

The first reconnect implementation consumes provenance-engine `0.1.0` at
commit b73fd1639c1c81230e96215259fc796b517706f6.

The session-tree reconnect implementation consumes provenance-engine commit
dbdc4b7e8b33bc0dc9c160d0f23501d2062e213e because Slice C SDK readiness is not
yet released as a versioned tag.

The first adapter dependency was pinned by released package version. The session-tree adapter is pinned by exact revision, not by a floating branch, until the engine readiness commit is tagged.

## API Surface And Verification

The completed adapter path calls:

- ProvenanceEngineClientFactory from ProvenanceEngineSDK
- ProvenanceEngineClient.worktrees
- ProvenanceWorktreeListRequest with repositoryID nil and limit nil
- ProvenanceWorktreeListResponse

Verification preserved the existing worktree-list JSON shape, text shape,
missing database behavior, empty database behavior, newest-first ordering, and
25-row text cap.

The worktree-list CLI fixture now seeds engine data through
ProvenanceEngineSDK and public contracts, not by depending on engine internal
SQLite tables.

If engine storage is missing or unavailable, the CLI must keep the existing
bounded command shape and reason output without mutating storage.

Rollback for this first adapter path is a scoped git revert, not a permanent
production dual-read path back to old bmux provenance tables.

The bmux CLI remains responsible for command parsing, localized usage and
errors, missing-database fallback output, snake_case JSON compatibility, text
rendering, the current 25-row text cap, and the existing database-path option.

The engine remains responsible for opening and migrating engine-owned SQLite
storage, reading worktree and linked repository projections, preserving query
order in the domain response, and returning contract DTOs instead of
table-shaped rows.

Engine release `0.1.0` publicly exports ProvenanceEngineContracts and
ProvenanceEngineSDK. ProvenanceEngineSDK creates SQLite-backed
`any ProvenanceEngineClient` values through ProvenanceEngineClientFactory.
ProvenanceEngineSQLite remains an internal target and is not a public library
product.

## Completion Record

Tests added or changed: `bmuxTests/WorkProvenanceStoreTests.swift` covers the
external SDK-backed worktree list query, and `tests/test_provenance_cli.py`
preserves the CLI JSON/text/no-database/empty-database behavior with public SDK
fixture seeding.

Legacy code removed for this path: local duplicate worktree-list DTOs and the
direct SQLite `CLIProvenanceSQLiteReader.worktreeList()` implementation.

Legacy code intentionally retained: bmux-local storage, projections, lifecycle
capture, and all unmigrated read paths remain until their own scoped migration
slices.

Known finding: the first adoption slice was successful enough to continue. Slice
B later clarified the local legacy client seam as `BmuxLegacyProvenanceClient`
so the remaining bmux-local paths are searchable and intentionally
transitional.

Second target complete in bmux: Slice C, session-tree read migration.

Next target after shared milestone acceptance: file-explanation read migration.

## Not Included

The completed worktree-list slice did not start further SDK expansion, daemon
work, IPC, launch agents, storage default changes, schema movement, data
migration, lifecycle recording reconnect, observability reconnect, retrieval,
lifecycle policy, UI, warnings, handoff recommendations, or broad telemetry
changes.

Data migration belongs to ADR-001 Phase 5.
Semantic roadmap Phases 5 through 8 belong after the first foundation/adoption
work and must not be implemented as part of this first reconnect.
