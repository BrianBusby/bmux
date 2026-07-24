# Provenance Engine Adoption History

Status: archival history for completed and candidate adoption slices.

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

## 2026-07-24 Session-Tree Read Adoption

Accepted provenance-engine default-branch revision
`2026914454a00ccc6c45d686ea741111b0a01229`, the merge commit for
`slice-c-session-tree-read-contract`.

Merged bmux PR 7 (`https://github.com/BrianBusby/bmux/pull/7`) with the normal
GitHub merge method at `08763dd0d3256989180dcc04f426da1f24369175` on
2026-07-24T17:20:04Z. Final PR head:
`322629bf0fa0bd19367f090bdfcf1bc21c6a1e95`.

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
  included sessions. bmux translated the cap to a combined row limit. The engine
  returns relationships only for child sessions included within the limit, then
  returns external identities for included sessions. This is now documented in
  the engine integration contract and is not a current contract defect.
- Missing abstraction: none for this read path.
- Implementation detail leakage: none on the migrated path. Tests seed through
  public `appendEvent`; no session-tree CLI test reads engine tables directly.

Final local validation: final `slice-c-main` tagged Debug reload passed; provenance CLI integration tests passed against the tagged bundled CLI; targeted `WorkProvenanceStoreTests` and `SubsessionProvenanceTests` passed; pbxproj, Package.resolved policy, workspace package grouping, whitespace, and active-path prohibited-import/table scans passed.

GitHub Actions waiver: bmux PR 7 Actions did not complete because PR-event CI
and Activation performance runs remained pending with zero jobs/check runs,
while manually dispatched runs queued without runner assignment on
`blacksmith-4vcpu-ubuntu-2404`. No failing CI result was observed, `main` had
no required status-check branch protection, and acceptance relied on the local
validation suite above. This waiver applies only to Slice C and does not
permanently remove CI expectations; runner or workflow scheduling should be
tracked separately as repository infrastructure work in
`https://github.com/BrianBusby/bmux/issues/8`.

Dependency decision: use merged default-branch revision `2026914454a00ccc6c45d686ea741111b0a01229` until a later release or tag includes Slice C.

Classification: Adoption accepted - continue.

Next recommendation: migrate the file-explanation read path in a new focused
Slice D branch or session. No engine contract changes are required before that
slice. The only follow-up is to replace the merged revision pin with a later
release/tag if one is created.

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
