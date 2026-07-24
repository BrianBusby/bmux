# Provenance Engine Adoption

Status: Slice D file-explanation read adoption accepted. Slice C session-tree read migration and Slice D file-explanation read migration are both accepted with explicit GitHub Actions waivers for bmux PR 7 and PR 9.

Merged Slice C adoption: `https://github.com/BrianBusby/bmux/pull/7` merged with the
normal GitHub merge method at
`08763dd0d3256989180dcc04f426da1f24369175` on 2026-07-24T17:20:04Z. Final PR
head: `322629bf0fa0bd19367f090bdfcf1bc21c6a1e95`.

Merged Slice D adoption: `https://github.com/BrianBusby/bmux/pull/9` merged with the
normal GitHub merge method at
`c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` on 2026-07-24T21:54:46Z. Final PR
head: `ea72bfd7dc28cd60b093b5a4d0bebc5853c32f59`.

Planning authority: this is the bmux-local adoption inventory and implementation state. The canonical cross-repository roadmap is `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

## Current State

bmux consumes provenance-engine as an external Swift package pinned to merged engine revision `126afde36671f53a137953200e7883e6b4093ac3`. The temporary Slice D readiness pin `384026e36087dda576e25343907c3e06d8a4d594` has been removed everywhere.

The Xcode project links `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. The adopted runtime paths are `bmux provenance worktrees list`, `bmux provenance sessions tree <session-id>`, and `bmux provenance explain <path>`.

The worktree path constructs an external SQLite-backed client with `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls `ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`. The session-tree path uses the same factory and calls `ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(...))`. The file-explanation path uses the same factory, resolves the matching engine worktree through `worktrees(...)`, and calls `ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest(...))` with the repository-relative path.

bmux still owns CLI parsing, fallback messages, JSON/text presentation, and output compatibility.

## File-Explanation Adoption Completion

Slice D is accepted. Provenance Engine PR 5 merged at `126afde36671f53a137953200e7883e6b4093ac3`, and bmux PR 9 merged the adoption at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374`.

Verified from code: `Package.resolved` pins provenance-engine revision
`126afde36671f53a137953200e7883e6b4093ac3`; `BMUXCLI+Provenance.swift`
constructs the external client for `runProvenanceExplain`; bmux resolves the
Git worktree root and repository-relative path; the adopted path resolves the
engine worktree through `client.worktrees(ProvenanceWorktreeListRequest())`;
and the command calls
`client.fileExplanation(ProvenanceFileExplanationRequest(worktreeID:path:))`.

Compatibility preserved: attributed file, unattributed file, unknown file,
missing database, path outside Git worktree, no Git worktree, no matching engine
worktree, relative input path, absolute input path, JSON output, text output,
unknown flags, extra arguments, and exit status.

Legacy code removed for this path: direct file-explanation SQL on
`CLIProvenanceSQLiteReader`, `WorkProvenanceStore.fileExplanation(...)`,
`BmuxLegacyProvenanceClient.fileExplanation`, duplicate bmux-local
file-explanation request/response DTOs, `CLIProvenanceExplanationRow`, and
direct SQLite-seeded file-explanation CLI fixtures.

Legacy code intentionally retained: `WorkProvenanceStore`, current-context SQL,
event/projection storage, lifecycle/capture paths, observability traces, and
presentation adapters remain because they are used by unmigrated paths or
bmux-owned rendering.

Integration findings: no engine contract concern was found. The existing
public `fileExplanation` request/response represented the current bmux CLI
behavior cleanly. The only integration friction is release management: bmux
now consumes the merged engine commit rather than a temporary feature-branch pin.
Future architecture concerns remain rename-aware identity, historical
explanations, and deleted-file reconstruction; none should change Slice D V1.

Architecture Review:

1. The migration reinforced the platform/consumer boundary: the engine owns the
   domain query and storage access, while bmux owns parsing, Git path
   normalization, fallback policy, and rendering.
2. The existing public contract was sufficient in real use.
3. bmux did not need knowledge of engine storage.
4. Path normalization is owned by the correct layer: bmux converts user input to
   `(worktreeID, repository-relative path)`, and the engine performs exact
   matching.
5. The response did not require awkward presentation adaptation; bmux uses a
   narrow adapter to keep legacy JSON/text shapes stable.
6. Consumer capability unlocked: bmux can explain files entirely through public
   engine contracts while preserving product-specific CLI behavior.
7. Removed debt: file-explanation-only local SQL, local DTO duplication, legacy
   client method, and direct-storage CLI fixture seeding.
8. Remaining debt: current-context reads, lifecycle/capture writes, local
   projection storage, and observability traces remain bmux-local until later
   slices.
9. Future architecture concerns: rename-aware and historical file identity
   remain out of scope for V1.
10. Overall confidence: Architecture validated.

## Session-Tree Adoption Completion

The session-tree adoption slice is accepted.

Verified from code: `Package.resolved` pins provenance-engine revision `2026914454a00ccc6c45d686ea741111b0a01229`; `BMUXCLI+Provenance.swift` constructs the external client for `runProvenanceSessions`; the adopted path calls `client.sessionTree(ProvenanceEngineContracts.ProvenanceSessionTreeRequest(...))`; the CLI maps external DTOs into bmux-owned presentation payloads; the old direct `CLIProvenanceSQLiteReader.sessionTree()` implementation is absent; the local legacy `BmuxLegacyProvenanceClient.sessionTree` method and duplicate bmux-local session-tree request/response DTOs are absent; the CLI session-tree fixture seeds through public engine APIs.

Compatibility preserved: JSON shape, text shape, missing-database behavior, no-session behavior, depth-first ordering, relationship and external identity rendering, and the legacy 100-session cap. The adapter translates bmux's legacy 100-session cap to the engine's combined session-plus-relationship row limit. The engine returns relationships only for returned child sessions and external identities for included sessions; consumers should not treat the engine limit as a presentation cap.

## Worktree Adoption Completion

The worktree-list adoption slice is complete.

Verified from code: `Package.resolved` pins provenance-engine `0.1.0`; `project.pbxproj` links `ProvenanceEngineContracts` and `ProvenanceEngineSDK`; `BMUXCLI+Provenance.swift` constructs the external client only for `runProvenanceWorktrees`; the adopted path calls `client.worktrees(ProvenanceWorktreeListRequest())`; the CLI maps external DTOs into bmux-owned presentation payloads; the old `CLIProvenanceSQLiteReader.worktreeList()` reader is absent; Swift and Python CLI fixtures seed worktree data through public engine APIs.

Compatibility preserved: JSON shape, text shape, missing-database behavior, empty-database behavior, newest-first ordering, and the 25-row text rendering cap.

## Slice B Boundary Clarification

The bmux-local contract-shaped client is now explicitly named `BmuxLegacyProvenanceClient`. `WorkProvenanceStore` conforms through `WorkProvenanceStore+BmuxLegacyProvenanceClient.swift`.

This rename only clarifies the transitional local boundary. It does not rename, wrap, or alias the external `ProvenanceEngineContracts.ProvenanceEngineClient`, which remains the accepted engine API for migrated paths.

## Migration State

The repository is in a controlled incremental migration. The external engine is the target owner of durable provenance storage and domain queries. bmux remains the owner of capture orchestration, CLI/UI presentation, command parsing, fallback text, and workflow policy.

Do not keep permanent dual reads. A migrated path is complete only when runtime calls the external engine, tests seed through public APIs, duplicate local query implementation is removed, and documentation reflects the current boundary.

## Remaining Bmux-Local Consumer Inventory

The external engine owns durable facts: immutable provenance events, repository/worktree/session/file/change/checkpoint/validation projections, schema migration, and domain query DTOs. bmux owns capture orchestration, runtime context selection, command parsing, fallback messages, and JSON/text/UI presentation.

| Consumer | Class | Command or runtime path | Current implementation | Local protocol methods used | Storage/projection dependencies | External engine API exists in `0.1.0` | Proposed migration order | Deletable legacy code after migration |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Worktree list CLI | read, presentation | `bmux provenance worktrees list` | Already migrated in `CLI/BMUXCLI+Provenance.swift` through `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)`. | None. | External engine worktree/repository projections. bmux still owns CLI fallback and rendering. | Yes: `worktrees`. | Done. | Local `CLIProvenanceSQLiteReader.worktreeList()` and local worktree-list DTO duplication already removed. |
| Session tree CLI | read, presentation | `bmux provenance sessions tree <session-id>` | Already migrated in `CLI/BMUXCLI+Provenance.swift` through `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)`. | None. | External engine session, relationship, and external identity projections. bmux still owns CLI fallback and rendering. | Yes: `sessionTree`. | Done, Slice C. | Local direct CLI SQLite session-tree reader, duplicate bmux-local session-tree request/response DTOs, `BmuxLegacyProvenanceClient.sessionTree`, and raw SQLite CLI fixture seeding for this path were removed. `WorkProvenanceStore.sessionTree(rootSessionID:limit:)` intentionally remains for lifecycle/capture projection tests until a later lifecycle/storage slice. |
| File explanation CLI | read, presentation | `bmux provenance explain <path>` | Accepted Slice D path resolves the Git target in bmux, resolves the matching engine worktree through `ProvenanceEngineClient.worktrees(...)`, then calls `ProvenanceEngineClient.fileExplanation(...)`. | None. | External engine worktree, repository, file-change, change-set, checkpoint, contribution, session, and work-item projections. bmux still owns CLI fallback and rendering. | Yes: `fileExplanation`. | Done, Slice D. | Direct file-explanation SQL on `CLIProvenanceSQLiteReader`, `WorkProvenanceStore.fileExplanation(...)`, `BmuxLegacyProvenanceClient.fileExplanation`, duplicate bmux-local file-explanation DTOs, and direct-storage file-explanation fixtures were removed. |
| Current context CLI | read, presentation, policy | `bmux provenance context current` | CLI resolves the current Git target, constructs `WorkProvenanceStore`, and calls `BmuxLegacyProvenanceClient.currentContext(...)` with bmux-owned default section limits. | `currentContext`. | Local `worktrees`, `repositories`, active `sessions`, `work_contributions`, `work_items`, latest `file_changes`, `change_sets`, `checkpoints`, `validation_runs`, and conflict projection SQL. | Yes: `currentContext`. | 3, after file explanation. | `WorkProvenanceStore.currentContext(...)`, `currentContext*` SQL helpers, the `currentContext` method on `BmuxLegacyProvenanceClient`, and local current-context response tests/seeding. |
| Subsession lifecycle capture | capture, write, policy, observability | App runtime: `AppDelegate` wires `AgentChatTranscriptService.recordSubsessionLifecycleChanges(with:)`; hook events call `WorkProvenanceRuntime.recordSubsessionLifecycleChange(...)`; recorder builds lifecycle events. | `WorkProvenanceSubsessionLifecycleRecorder` resolves child identity, reads parent relationship from `WorkProvenanceStore`, appends through `appendWithStageTrace(...)`, and optionally writes observability trace rows. | None on `BmuxLegacyProvenanceClient`; legacy direct store methods are `parentSession(for:)` and `appendWithStageTrace(...)`. | Local `events`, `sessions`, `session_relationships`, `session_external_identities`, and lifecycle observability tables. | Yes for durable write: `recordSubsessionLifecycle` and `appendEvent`. No external observability API. | 4, after read paths prove contract compatibility. | Local lifecycle append path in `WorkProvenanceSubsessionLifecycleRecorder`, `ProvenanceSubsessionLifecycleRecording` local seam if no longer needed for bmux tests, `appendWithStageTrace(...)` coupling to `WorkProvenanceStore`, and parent-relationship direct read once identity/root computation moves to engine or a bmux adapter contract. |
| Worktree observation capture | capture, write, policy | App runtime: `bmuxApp` creates `WorkProvenanceRuntime.live()`; `TabManager.workspaceTabsWillChange` and current-directory notifications call `observeWorkspaces`. | `WorkProvenanceObservationService` snapshots Git state, applies duplicate-fingerprint policy, builds `worktree_observed` events, appends to `WorkProvenanceStore`, and prunes observed history. | None on `BmuxLegacyProvenanceClient`; direct store methods are `append(_:)` and `pruneExpiredObservedHistory(now:)`. | Local event ledger plus repository/worktree/change-set/file-change projections and local retention pruning. | Yes for durable event append: `appendEvent`. No engine API should own bmux Git snapshot capture or duplicate-fingerprint policy. | 5, after lifecycle write or alongside a focused append adapter slice. | Direct `WorkProvenanceStore.append(_:)`/retention use from `WorkProvenanceObservationService`, local projection update code for observed worktree events, and eventually local retention SQL if engine owns event-retention policy. Capture adapters and Git inspection remain bmux-owned. |
| Runtime composition | capture, policy | App startup in `bmuxApp.init()` and `WorkProvenanceRuntime.live()`. | Constructs local `WorkProvenanceStore`, `ProvenanceObservabilityStore`, observation service, and lifecycle recorder from bmux state paths. | None directly. | Local bmux work-provenance SQLite and observability SQLite paths under `~/.local/state/bmux/work-provenance`. | Yes for engine client construction: `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)`; storage relocation/data migration is not part of Slice B. | 6, after all runtime reads/writes stop depending on local store internals. | `WorkProvenanceRuntime.live()` local store construction and local database URL ownership for authoritative provenance facts. Keep bmux-owned runtime degradation and capture wiring. |
| Lifecycle trace CLI | observability, presentation | `bmux provenance traces lifecycle-ingestion` | CLI opens bmux observability SQLite through `CLIProvenanceObservabilitySQLiteReader` and renders lifecycle ingestion traces. | None. | Local `ProvenanceObservabilityStore` tables: `pipeline_runs`, `pipeline_stage_executions`, `identity_resolution_attempts`, and `projection_lineage`. | No accepted external observability API; roadmap says observability must not expand ahead of migration needs. | 7, after durable lifecycle writes are migrated and an explicit observability contract is accepted. | `CLIProvenanceObservabilitySQLiteReader`, `ProvenanceLifecycleTraceQuerying`, `ProvenanceObservabilityStore+ProvenanceLifecycleTraceQuerying`, and lifecycle trace DTO/presentation code only if replaced by an engine-owned observability/read API. |
| Legacy store tests | read, write, capture, policy, observability | `bmuxTests/WorkProvenanceStoreTests.swift`, `SubsessionProvenanceTests.swift`, `WorkProvenanceObserverTests.swift`, and CLI fixture tests. | Tests instantiate local stores/recorders/services directly. `WorkProvenanceStoreTests` aliases the local seam as `TestBmuxLegacyProvenanceClient` to avoid colliding with external contracts. | `appendEvent` and `currentContext` where testing the remaining legacy seam. Local projection assertions remain for unmigrated capture/lifecycle behavior. | Temporary local SQLite fixtures and local projections. | Engine APIs exist for durable query/write paths except lifecycle observability. | Per migrated slice. | Legacy seam tests for a method become deletable when the corresponding runtime path uses external engine APIs and equivalent behavior is covered through public engine seeding plus bmux presentation tests. |

## Architectural Findings

- The name collision was real: bmux-local `ProvenanceEngineClient` and external `ProvenanceEngineContracts.ProvenanceEngineClient` existed in the same CLI and test contexts. `BmuxLegacyProvenanceClient` makes remaining local usage searchable and intentionally transitional.
- The accepted external `0.1.0` baseline exposed the session-tree API symbols, but bmux needed the later Slice C readiness commit for SDK-tested adoption evidence. A release/tag should follow before downstream consumers avoid revision pins.
- The session-tree contract was sufficient for the CLI read path. The only adaptation was limit semantics: bmux's legacy cap was session-count oriented, while the engine request limit is combined session-plus-relationship rows.
- The file-explanation contract was sufficient for the CLI read path. bmux preserved path parsing, Git worktree discovery, missing-database preflight, fallback rendering, and JSON/text compatibility while consuming only public engine contracts.
- Slice C waived unavailable GitHub Actions evidence for bmux PR 7 only:
  PR-event CI and Activation performance runs remained pending with zero
  jobs/check runs, manually dispatched runs queued without assignment to
  `blacksmith-4vcpu-ubuntu-2404`, no failing CI result was observed, and branch
  protection did not require those checks.
- Slice D waived unavailable GitHub Actions evidence for bmux PR 9 only:
  final-head PR-event CI run `30129193072` and Activation performance run
  `30129193044` remained pending with zero jobs materialized, earlier PR-head
  jobs queued without runner assignment, no failing CI result was observed, and
  branch protection did not require checks. CI reliability remains
  infrastructure work tracked in `https://github.com/BrianBusby/bmux/issues/8`.
- bmux-specific capture and policy should stay outside the engine: Git snapshot scheduling, duplicate-fingerprint suppression, command parsing, fallback text, output formatting, UI routing, and runtime degradation.
- The local store still mixes engine-owned durable facts with bmux-owned capture policy and observability trace writes. Migration should remove direct store reads/writes slice by slice instead of creating permanent dual paths.

## Next Target

Active target: none selected after Slice D acceptance.

The next eligible migration target is `bmux provenance context current`, but no next slice is active in this handoff.

Do not begin current-context implementation, lifecycle-write, capture, observability,
data-migration, daemon, UI, or engine-expansion work until a new slice is explicitly selected.
