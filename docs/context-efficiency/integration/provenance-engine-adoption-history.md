# Provenance Engine Adoption History

Status: archival history for completed adoption slices.

## 2026-07-22 Worktree List Adoption

Accepted provenance-engine `0.1.0` at revision
`b73fd1639c1c81230e96215259fc796b517706f6`.

The bmux branch `provenance-engine-worktrees-adoption` pinned the external
package to exact version `0.1.0`, linked `ProvenanceEngineContracts` and
`ProvenanceEngineSDK`, and reconnected only `bmux provenance worktrees list`
through the public SDK factory.

The adopted path uses
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`.

CLI presentation stayed in bmux. JSON/text output compatibility,
missing-database behavior, empty-database behavior, newest-first ordering, and
the 25-row text cap were preserved.

Local duplicate worktree-list DTO files were removed. The old direct SQLite
worktree-list reader on `CLIProvenanceSQLiteReader` was removed.

The slice intentionally retained the legacy bmux-local store, event/projection
storage, capture runtime, lifecycle recording, and unmigrated read paths.

No daemon, IPC, storage move, schema migration, data migration, semantic
retrieval, observability expansion, UI work, or additional read-path migration
was started.
