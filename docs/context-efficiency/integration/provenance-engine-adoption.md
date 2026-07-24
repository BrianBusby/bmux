# Provenance Engine Adoption

Status: Slice C session-tree read migration accepted on 2026-07-24 with an
explicit GitHub Actions waiver for bmux PR 7.

Planning authority: this is the bmux-local adoption inventory and implementation state. The canonical cross-repository roadmap is `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

## Current State

bmux consumes provenance-engine as an external Swift package pinned to revision `2026914454a00ccc6c45d686ea741111b0a01229`. The pin is a merged default-branch revision rather than version `0.1.0` because Slice C readiness is not yet released as a tag.

The Xcode project links `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. The adopted runtime paths are `bmux provenance worktrees list` and `bmux provenance sessions tree <session-id>`.

The worktree path constructs an external SQLite-backed client with `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls `ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`. The session-tree path uses the same factory and calls `ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(...))`.

bmux still owns CLI parsing, fallback messages, JSON/text presentation, and output compatibility.

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
| File explanation CLI | read, presentation | `bmux provenance explain <path>` | CLI resolves the Git target, uses `WorkProvenanceStore.worktree(path:)` and `repository(id:)` for fallback/presentation context, then calls `BmuxLegacyProvenanceClient.fileExplanation(...)`. | `fileExplanation`. | Local `worktrees`, `repositories`, `file_changes`, `change_sets`, `checkpoints`, `work_contributions`, `sessions`, and `work_items` projections. | Yes: `fileExplanation`. | 2, after session-tree read migration. | `WorkProvenanceStore.fileExplanation(worktreeID:path:)`, direct `worktree(path:)`/`repository(id:)` fallback reads if replaced by engine response/fallback DTOs, the `fileExplanation` method on `BmuxLegacyProvenanceClient`, and local file-explanation response tests/seeding. |
| Current context CLI | read, presentation, policy | `bmux provenance context current` | CLI resolves the current Git target, constructs `WorkProvenanceStore`, and calls `BmuxLegacyProvenanceClient.currentContext(...)` with bmux-owned default section limits. | `currentContext`. | Local `worktrees`, `repositories`, active `sessions`, `work_contributions`, `work_items`, latest `file_changes`, `change_sets`, `checkpoints`, `validation_runs`, and conflict projection SQL. | Yes: `currentContext`. | 3, after file explanation. | `WorkProvenanceStore.currentContext(...)`, `currentContext*` SQL helpers, the `currentContext` method on `BmuxLegacyProvenanceClient`, and local current-context response tests/seeding. |
| Subsession lifecycle capture | capture, write, policy, observability | App runtime: `AppDelegate` wires `AgentChatTranscriptService.recordSubsessionLifecycleChanges(with:)`; hook events call `WorkProvenanceRuntime.recordSubsessionLifecycleChange(...)`; recorder builds lifecycle events. | `WorkProvenanceSubsessionLifecycleRecorder` resolves child identity, reads parent relationship from `WorkProvenanceStore`, appends through `appendWithStageTrace(...)`, and optionally writes observability trace rows. | None on `BmuxLegacyProvenanceClient`; legacy direct store methods are `parentSession(for:)` and `appendWithStageTrace(...)`. | Local `events`, `sessions`, `session_relationships`, `session_external_identities`, and lifecycle observability tables. | Yes for durable write: `recordSubsessionLifecycle` and `appendEvent`. No external observability API. | 4, after read paths prove contract compatibility. | Local lifecycle append path in `WorkProvenanceSubsessionLifecycleRecorder`, `ProvenanceSubsessionLifecycleRecording` local seam if no longer needed for bmux tests, `appendWithStageTrace(...)` coupling to `WorkProvenanceStore`, and parent-relationship direct read once identity/root computation moves to engine or a bmux adapter contract. |
| Worktree observation capture | capture, write, policy | App runtime: `bmuxApp` creates `WorkProvenanceRuntime.live()`; `TabManager.workspaceTabsWillChange` and current-directory notifications call `observeWorkspaces`. | `WorkProvenanceObservationService` snapshots Git state, applies duplicate-fingerprint policy, builds `worktree_observed` events, appends to `WorkProvenanceStore`, and prunes observed history. | None on `BmuxLegacyProvenanceClient`; direct store methods are `append(_:)` and `pruneExpiredObservedHistory(now:)`. | Local event ledger plus repository/worktree/change-set/file-change projections and local retention pruning. | Yes for durable event append: `appendEvent`. No engine API should own bmux Git snapshot capture or duplicate-fingerprint policy. | 5, after lifecycle write or alongside a focused append adapter slice. | Direct `WorkProvenanceStore.append(_:)`/retention use from `WorkProvenanceObservationService`, local projection update code for observed worktree events, and eventually local retention SQL if engine owns event-retention policy. Capture adapters and Git inspection remain bmux-owned. |
| Runtime composition | capture, policy | App startup in `bmuxApp.init()` and `WorkProvenanceRuntime.live()`. | Constructs local `WorkProvenanceStore`, `ProvenanceObservabilityStore`, observation service, and lifecycle recorder from bmux state paths. | None directly. | Local bmux work-provenance SQLite and observability SQLite paths under `~/.local/state/bmux/work-provenance`. | Yes for engine client construction: `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)`; storage relocation/data migration is not part of Slice B. | 6, after all runtime reads/writes stop depending on local store internals. | `WorkProvenanceRuntime.live()` local store construction and local database URL ownership for authoritative provenance facts. Keep bmux-owned runtime degradation and capture wiring. |
| Lifecycle trace CLI | observability, presentation | `bmux provenance traces lifecycle-ingestion` | CLI opens bmux observability SQLite through `CLIProvenanceObservabilitySQLiteReader` and renders lifecycle ingestion traces. | None. | Local `ProvenanceObservabilityStore` tables: `pipeline_runs`, `pipeline_stage_executions`, `identity_resolution_attempts`, and `projection_lineage`. | No accepted external observability API; roadmap says observability must not expand ahead of migration needs. | 7, after durable lifecycle writes are migrated and an explicit observability contract is accepted. | `CLIProvenanceObservabilitySQLiteReader`, `ProvenanceLifecycleTraceQuerying`, `ProvenanceObservabilityStore+ProvenanceLifecycleTraceQuerying`, and lifecycle trace DTO/presentation code only if replaced by an engine-owned observability/read API. |
| Legacy store tests | read, write, capture, policy, observability | `bmuxTests/WorkProvenanceStoreTests.swift`, `SubsessionProvenanceTests.swift`, `WorkProvenanceObserverTests.swift`, and CLI fixture tests. | Tests instantiate local stores/recorders/services directly. `WorkProvenanceStoreTests` aliases the local seam as `TestBmuxLegacyProvenanceClient` to avoid colliding with external contracts. | `appendEvent`, `fileExplanation`, `currentContext` where testing the legacy seam. Local `WorkProvenanceStore.sessionTree` remains for direct projection assertions, not the legacy client seam. | Temporary local SQLite fixtures and local projections. | Engine APIs exist for durable query/write paths except lifecycle observability. | Per migrated slice. | Legacy seam tests for a method become deletable when the corresponding runtime path uses external engine APIs and equivalent behavior is covered through public engine seeding plus bmux presentation tests. |

## Architectural Findings

- The name collision was real: bmux-local `ProvenanceEngineClient` and external `ProvenanceEngineContracts.ProvenanceEngineClient` existed in the same CLI and test contexts. `BmuxLegacyProvenanceClient` makes remaining local usage searchable and intentionally transitional.
- The accepted external `0.1.0` baseline exposed the session-tree API symbols, but bmux needed the later Slice C readiness commit for SDK-tested adoption evidence. A release/tag should follow before downstream consumers avoid revision pins.
- The session-tree contract was sufficient for the CLI read path. The only adaptation was limit semantics: bmux's legacy cap was session-count oriented, while the engine request limit is combined session-plus-relationship rows.
- Slice C waived unavailable GitHub Actions evidence for bmux PR 7 only:
  PR-event CI and Activation performance runs remained pending with zero
  jobs/check runs, manually dispatched runs queued without assignment to
  `blacksmith-4vcpu-ubuntu-2404`, no failing CI result was observed, and branch
  protection did not require those checks. CI reliability must be tracked as
  infrastructure work outside Slice D.
- bmux-specific capture and policy should stay outside the engine: Git snapshot scheduling, duplicate-fingerprint suppression, command parsing, fallback text, output formatting, UI routing, and runtime degradation.
- The local store still mixes engine-owned durable facts with bmux-owned capture policy and observability trace writes. Migration should remove direct store reads/writes slice by slice instead of creating permanent dual paths.

## Next Target

Active target: Slice D file-explanation read migration.

Exact next scope: migrate only `bmux provenance explain <path>` to construct
the external SQLite-backed engine client and call
`ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest(...))`;
preserve existing JSON/text/no-database/no-worktree/no-file behavior and bounds;
seed tests through public engine APIs where applicable; remove
file-explanation-only local query helpers that become unused.

Do not begin current-context, lifecycle-write, capture, observability,
data-migration, daemon, UI, or engine-expansion work in the file-explanation
slice.
