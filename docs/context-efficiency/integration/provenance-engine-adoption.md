# Provenance Engine Adoption

Status: Slice A reconciliation on 2026-07-23.

## Current State

bmux consumes provenance-engine as an external Swift package pinned to version `0.1.0` at revision `b73fd1639c1c81230e96215259fc796b517706f6`.

The Xcode project links `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. The adopted runtime path is `bmux provenance worktrees list`.

That path constructs an external SQLite-backed client with `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls `ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`.

bmux still owns CLI parsing, fallback messages, JSON/text presentation, and output compatibility.

## Worktree Adoption Completion

The worktree-list adoption slice is complete.

Verified from code: `Package.resolved` pins provenance-engine `0.1.0`; `project.pbxproj` links `ProvenanceEngineContracts` and `ProvenanceEngineSDK`; `BMUXCLI+Provenance.swift` constructs the external client only for `runProvenanceWorktrees`; the adopted path calls `client.worktrees(ProvenanceWorktreeListRequest())`; the CLI maps external DTOs into bmux-owned presentation payloads; the old `CLIProvenanceSQLiteReader.worktreeList()` reader is absent; Swift and Python CLI fixtures seed worktree data through public engine APIs.

Compatibility preserved: JSON shape, text shape, missing-database behavior, empty-database behavior, newest-first ordering, and the 25-row text rendering cap.

## Migration State

The repository is in a controlled incremental migration. The external engine is the target owner of durable provenance storage and domain queries. bmux remains the owner of capture orchestration, CLI/UI presentation, command parsing, fallback text, and workflow policy.

Do not keep permanent dual reads. A migrated path is complete only when runtime calls the external engine, tests seed through public APIs, duplicate local query implementation is removed, and documentation reflects the current boundary.

## Next Target

Next target: Slice B, legacy boundary clarification.

Slice B should rename the bmux-local provenance protocol so it cannot be confused with the external `ProvenanceEngineClient`, then inventory every remaining local provenance consumer before any second read path is migrated.

Do not begin session-tree migration until Slice B and the first integration findings review are accepted.
