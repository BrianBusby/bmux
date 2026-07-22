# Provenance Engine Extraction: Phase 4 Reconnect Plan

Status: drafted on 2026-07-22 for ADR-001 Phase 4 planning only.

Inputs:

- ADR-001 provenance extraction record.
- Phase 1 contract plan.
- Phase 3 plan.
- Engine commit b0cc65f42065b5d8e0ac3be3c45a22ce0d4013d5.
- bmux commit b1e7f7edbc00f84c6f3ff96c2afd6f432f5ad4ce.

## Purpose

Phase 4 reconnects bmux to the independent Provenance Engine after the
contracts and internal engine-owned SQLite implementation exist outside bmux.

This document is a planning gate only.

It chooses the first bmux adapter path to replace.

Implementation must not start until the gates below are satisfied.

## First Adapter Path

Replace the read path behind bmux provenance worktrees list.

Reasons:

- It is the narrowest existing Phase 2 CLI conversion.
- It is query-only.
- It does not need Git target resolution or repository-relative file mapping.
- It does not touch session-tree recursion or observability trace reads.
- It already calls the contract-shaped ProvenanceEngineClient.worktrees seam in
  bmux.
- Existing CLI coverage protects JSON shape, text shape, missing database
  behavior, empty database behavior, newest-first ordering, and the text cap.

Do not use the first reconnect slice to replace provenance explain, provenance
context current, provenance sessions tree, lifecycle recording, observability
traces, capture adapters, storage defaults, or migration paths.

## Engine Version To Consume

Pin the first reconnect implementation to engine commit
b0cc65f42065b5d8e0ac3be3c45a22ce0d4013d5.

That commit is on branch provenance-session-tree-storage and draft PR
https://github.com/BrianBusby/provenance-engine/pull/1.

Do not consume a floating branch in bmux. If the engine PR moves before
implementation, update this plan to name the new exact commit or a released
package version before changing bmux.

## API Surface And Verification

The adapter path must call:

- ProvenanceEngineClient.worktrees
- ProvenanceWorktreeListRequest with repositoryID nil and limit nil
- ProvenanceWorktreeListResponse

Verification must preserve the existing worktree-list JSON shape, text shape,
missing database behavior, empty database behavior, newest-first ordering, and
25-row text cap.

The current Python fixtures create old bmux table names directly. The reconnect
verification must seed engine data through public contracts or a small SDK-backed
helper, not by depending on engine internal SQLite tables.

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

Current engine commit b0cc65f42065b5d8e0ac3be3c45a22ce0d4013d5 publicly
exports ProvenanceEngineContracts only. ProvenanceEngineSQLite exists as an
internal target and is not a public library product.

Before bmux reconnect code changes, the engine needs a deliberately small
public in-process SDK product or factory that returns an any
ProvenanceEngineClient backed by engine SQLite. That export is not part of this
planning slice.

## Not Included

This plan does not start Phase 4 implementation, public SDK export
implementation, daemon work, IPC, launch agents, storage default changes,
schema movement, data migration, deletion of duplicated bmux readers, lifecycle
recording reconnect, observability reconnect, retrieval, lifecycle policy, UI,
warnings, handoff recommendations, or broad telemetry changes.

Data migration belongs to ADR-001 Phase 5.
