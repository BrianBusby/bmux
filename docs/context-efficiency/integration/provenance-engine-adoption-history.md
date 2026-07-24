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

## 2026-07-23 Session-Tree Read Adoption

Accepted provenance-engine readiness revision
`dbdc4b7e8b33bc0dc9c160d0f23501d2062e213e` from branch
`slice-c-session-tree-read-contract`.

The bmux branch `slice-c-session-tree-read-migration` pins the external package
to that exact revision, links the already-public `ProvenanceEngineContracts` and
`ProvenanceEngineSDK` products, and reconnects only
`bmux provenance sessions tree <session-id>` through the public SDK factory.

The adopted path uses
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and
`ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(...))`.

CLI presentation stayed in bmux. JSON/text output compatibility,
missing-database behavior, no-session behavior, depth-first ordering,
relationship and external identity rendering, and the legacy 100-session cap
were preserved.

Legacy code removed for this path: the direct
`CLIProvenanceSQLiteReader.sessionTree()` SQL implementation and helper SQL, the
`BmuxLegacyProvenanceClient.sessionTree` method, and duplicate bmux-local
session-tree request/response DTOs.

Legacy code intentionally retained: `WorkProvenanceStore.sessionTree` and local
relationship/external-identity projection helpers remain because lifecycle and
capture tests still use them to assert bmux-local projection behavior. They are
not on the migrated CLI command path.

No file-explanation, current-context, lifecycle-write, capture,
observability, data-migration, daemon, UI, retrieval, GitHub ingestion, or
Knowledge Compiler work was started.

### Integration Findings

- What was easy: the command could mirror the existing worktree-list adapter by
  creating a SQLite client through `ProvenanceEngineClientFactory` and mapping
  public response DTOs into bmux-owned CLI payloads.
- What was awkward: the dependency had to move from released version `0.1.0` to
  an exact revision because Slice C readiness is not yet tagged.
- Public request and response sufficiency: `found`, `reason`, `sessions`,
  `relationships`, and `externalIdentities` were sufficient for the existing
  CLI JSON/text presentation.
- Ordering and presentation compatibility: bmux could preserve ordering and
  presentation without internal table access. bmux-specific payload keys and
  localized reason text stayed in bmux.
- Fallback behavior: missing database remains a bmux preflight so the engine
  does not create storage for a read-only fallback. No contract change is
  required for that policy, but adopters should document this pattern.
- Limit behavior: the engine limit is combined session-plus-relationship rows,
  while bmux's legacy CLI behavior was a 100-session cap with relationships for
  included sessions. bmux translated the cap to a combined row limit. This is a
  bmux compatibility concern and a future documentation question for the engine
  contract, not a current contract defect.
- Missing abstraction: none for this read path.
- Implementation detail leakage: none on the migrated path. Tests seed through
  public `appendEvent`; no session-tree CLI test reads engine tables directly.

Classification: Adoption successful - continue.

Next recommendation: after the shared Slice C milestone is accepted, migrate the
file-explanation read path. No engine contract changes are required before that
slice. The only follow-up is to release/tag the engine readiness revision before
depending consumers need a stable version pin.

### Slice Completion Architecture Review

1. Did the slice reinforce the Reference Architecture or expose a flaw?
   It reinforced the architecture. Provenance Engine owned the session-tree
   domain query and storage access; bmux owned parsing, fallback policy, and
   presentation.
2. Did any public APIs or integration boundaries feel awkward?
   The public API was sufficient. The awkwardness was release management and
   limit semantics, not missing data.
3. Did the work leak internal implementation details?
   No. The migrated path imports only `ProvenanceEngineContracts` and
   `ProvenanceEngineSDK`, and tests seed through public append events.
4. Should the Reference Architecture change, or is the learning limited to
   implementation or integration documentation?
   No Reference Architecture change is needed. Document the combined-row limit
   semantics and missing-database preflight pattern for adopters.
5. What can bmux users or the next consumer do that they could not do before?
   The session-tree CLI can now read through the public engine SDK, proving a
   second real consumer path without exposing SQLite internals.
6. What technical debt was intentionally introduced?
   A revision pin to an unreleased engine commit remains until the engine tags a
   release containing Slice C readiness. Local `WorkProvenanceStore.sessionTree`
   remains for lifecycle/capture projection tests until later migration slices.
7. What future opportunities emerged without becoming roadmap commitments?
   The same session relationship and external identity projections can inform
   lifecycle-write migration readiness, but lifecycle writes remain out of scope.
8. Overall confidence:
   Architecture validated.
