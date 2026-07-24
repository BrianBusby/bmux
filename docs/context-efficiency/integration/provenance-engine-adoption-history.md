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

## 2026-07-24 File-Explanation Read Adoption

Status: accepted.

Provenance Engine PR 5 (`https://github.com/BrianBusby/provenance-engine/pull/5`)
merged with the normal GitHub merge method at engine revision
`126afde36671f53a137953200e7883e6b4093ac3` on 2026-07-24T20:38:37Z. Final
engine PR head: `bf6c8c7ac6cddf1e44188ac288c1a125022d2e2b`.

Bmux PR 9 (`https://github.com/BrianBusby/bmux/pull/9`) merged with the normal
GitHub merge method at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` on
2026-07-24T21:54:46Z. Final bmux PR head:
`ea72bfd7dc28cd60b093b5a4d0bebc5853c32f59`.

The bmux adoption pins provenance-engine to merged revision
`126afde36671f53a137953200e7883e6b4093ac3`. The temporary readiness pin
`384026e36087dda576e25343907c3e06d8a4d594` was removed from the Xcode project,
workspace lockfile, fixture packages, fixture lockfiles, and dynamic CLI test
seeder fallback.

The adopted path uses
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)`, resolves the
engine worktree through
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`, and calls
`ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest(...))`
with the repository-relative path that bmux derives from user input.

CLI presentation stayed in bmux. JSON/text output compatibility, missing
database behavior, no Git worktree behavior, outside-worktree handling, no
matching engine worktree behavior, unknown-file behavior, attributed and
unattributed explanations, newest evidence selection, relative input paths,
absolute input paths, unknown-flag errors, extra-argument errors, and exit
status were preserved in local validation.

Legacy code removed for this path: direct file-explanation SQL on
`CLIProvenanceSQLiteReader`, `WorkProvenanceStore.fileExplanation(...)`,
`BmuxLegacyProvenanceClient.fileExplanation`, duplicate local file-explanation
request/response DTOs, `CLIProvenanceExplanationRow`, and direct-storage
file-explanation CLI fixture seeding.

Legacy code intentionally retained: current-context reads, event/projection
storage, lifecycle/capture writes, observability trace storage, and presentation
adapters remain because they are used by unmigrated paths or bmux-owned
rendering.

Final validation against `126afde36671f53a137953200e7883e6b4093ac3`:
file-explanation fixture `swift package resolve` passed; session-tree fixture
`swift package resolve` passed; Xcode package resolution passed; tagged reload
`./scripts/reload.sh --tag slice-d-acceptance` passed; provenance CLI
integration tests passed against the tagged bundled CLI; targeted
`WorkProvenanceStoreTests` and `WorkProvenanceObserverTests` passed 17 Swift
Testing tests; `scripts/check-pbxproj.sh`, Package.resolved policy, workspace
package grouping, and `git diff --check` passed; scans found no stale temporary
engine commit in dependency files, no `ProvenanceEngineSQLite` imports in
CLI/Sources/Packages/tests/bmuxTests, and no direct file-explanation table reads
in the migrated CLI path.

GitHub Actions waiver: bmux PR 9 final head
`ea72bfd7dc28cd60b093b5a4d0bebc5853c32f59` created PR-event CI run
`30129193072` and Activation performance run `30129193044`; both remained
pending with zero jobs materialized at final inspection. Earlier PR-head runs
for `46b9b94c8ac40d4b7358db189d44b4399c4f0ade` materialized queued jobs
without runner assignment: CI run `30123744339` jobs `89582203845` and
`89582203944`, and Activation performance run `30123744296` job `89582203380`,
all on `blacksmith-4vcpu-ubuntu-2404` with runner id 0 and no steps/logs or
conclusion. No failing CI result existed, `main` had no required status-check
branch protection, and acceptance relied on the local validation suite. This
waiver applies only to Slice D; runner scheduling remains tracked in
`https://github.com/BrianBusby/bmux/issues/8`.

Integration findings:

- Bmux concern: none beyond preserving existing Git path resolution and
  fallback policy in the consumer.
- Provenance Engine contract concern: none. The existing public
  file-explanation contract represented the current CLI behavior; no public API
  expansion was required.
- Future architecture concern: rename-aware identity, deleted-file historical
  lookup, and semantic explanations remain out of scope for Slice D V1.

Architecture Review:

1. Did the migration reinforce the platform/consumer boundary? Yes.
2. Was the existing public contract sufficient in real use? Yes.
3. Did bmux need knowledge of engine storage? No.
4. Is path normalization owned by the correct layer? Yes; bmux normalizes user
   input to repository-relative path plus engine worktree ID.
5. Did the response require awkward presentation adaptation? No.
6. What consumer capability is now unlocked? File explanations can be consumed
   through public engine SDK contracts.
7. What legacy code was removed? File-explanation-only SQL, DTOs, legacy client
   method, store method, and direct-storage fixtures.
8. What technical debt remains? Current-context, lifecycle/capture, projection
   storage, observability paths, and CI runner repair remain separate work.
9. What future architecture concerns remain deferred? V2 file identity,
   historical/deleted file reconstruction, semantic explanation, data
   migration, daemon transport, and broader migration slices.
10. Overall confidence: Architecture validated.

Classification: Adoption accepted - Slice D complete.

Next recommendation: the next migration slice may now be selected. The next
eligible migration target is `bmux provenance context current`, but this history
entry does not activate that slice.
