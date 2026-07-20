# Provenance Engine Extraction: Phase 0 Migration Report

Status: completed on 2026-07-20 for ADR-001 Phase 0.

ADR reference: `docs/context-efficiency/adr-001-provenance-engine-extraction.md`.

## Purpose

This report audits the current bmux provenance implementation before extracting an independent Provenance Engine. It identifies reusable engine candidates, bmux-specific adapters, direct-storage consumers, migration risks, and the first safe implementation targets.

No runtime behavior or schema changes were made in this phase.

## Current Implementation Summary

The current provenance-related implementation is split across three bodies:

| Body | Location | Current role | Extraction implication |
| --- | --- | --- | --- |
| `WorkProvenance` | `Sources/WorkProvenance/` | App-target semantic provenance event store, projections, Git observation, subsession lifecycle recording, and observability traces. | Primary reusable source for the engine, but currently coupled to bmux app models and app target tests. |
| `BmuxContextEfficiency` | `Packages/macOS/BmuxContextEfficiency/` | Swift package for local Codex rollout/state import, token/model/tool telemetry, command/reference facts, and bounded reports. | Good package precedent and telemetry source, but it is not the semantic provenance owner. It should integrate through SDK/API links and evidence references. |
| Provenance CLI readers | `CLI/BMUXCLI+Provenance.swift`, `CLI/CLIProvenance*.swift` | Read-only diagnostics over provenance SQLite tables and observability SQLite tables. | Must become a bmux client of the engine API. It currently violates ADR-001 by reading tables directly. |

## Provenance Modules

### Portable Engine Candidates

These files are strong extraction candidates after public contracts exist:

- `Sources/WorkProvenance/WorkProvenanceEvent.swift`
- `Sources/WorkProvenance/WorkProvenanceEventPayload.swift`
- `Sources/WorkProvenance/WorkProvenanceEventType.swift`
- `Sources/WorkProvenance/WorkProvenanceConfidence.swift`
- `Sources/WorkProvenance/WorkProvenanceSource.swift`
- `Sources/WorkProvenance/WorkProvenanceStableIDFactory.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `Sources/WorkProvenance/WorkProvenanceSQLiteDatabase.swift`
- `Sources/WorkProvenance/WorkProvenanceSQLiteStatement.swift`
- `Sources/WorkProvenance/WorkProvenanceStoreError.swift`
- `Sources/WorkProvenance/WorkProvenanceRetentionPolicy.swift`
- `Sources/WorkProvenance/WorkProvenancePruneResult.swift`
- record DTOs for repositories, worktrees, sessions, session relationships, external identities, work items, contributions, checkpoints, change sets, file changes, and validation runs.

Why these are candidates:

- They are already local-first and SQLite-backed.
- The core store uses an append-only `events` table plus rebuildable projections.
- Events carry schema version, type, source, confidence, and JSON payload.
- Projection rebuild is already supported by replaying stored events.
- Stable IDs are deterministic and hash-based.

### bmux Adapter Candidates

These should remain in bmux or become bmux-side adapters that call the engine SDK:

- `Sources/WorkProvenance/WorkProvenanceRuntime.swift`
- `Sources/WorkProvenance/WorkProvenanceObservationService.swift`
- `Sources/WorkProvenance/WorkProvenanceWorkspaceSnapshot.swift`
- `Sources/WorkProvenance/WorkProvenanceGitInspector.swift`
- `Sources/WorkProvenance/WorkProvenanceProcessGitCommandRunner.swift`
- `Sources/WorkProvenance/WorkProvenanceGit*`
- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`

Why these are adapters:

- `WorkProvenanceRuntime` directly owns bmux lifecycle wiring, creates stores under a bmux path, and references `TabManager`.
- `WorkProvenanceWorkspaceSnapshot` has a `@MainActor init(workspace: Workspace)` that depends on the bmux app model.
- `WorkProvenanceObservationService` observes bmux workspace snapshots and Git state; the normalized facts are portable, but the capture trigger is bmux-specific.
- `WorkProvenanceSubsessionLifecycleRecorder` consumes `AgentSubsessionLifecycleChange`, a bmux app type derived from hook/session registry state.

## Schemas And Storage

### WorkProvenance.sqlite

Current standard path:

```text
~/.local/state/bmux/work-provenance/bmux-work-provenance.sqlite
```

Schema version: `3`.

Tables:

- `events`
- `repositories`
- `worktrees`
- `sessions`
- `session_relationships`
- `session_external_identities`
- `work_items`
- `work_contributions`
- `checkpoints`
- `change_sets`
- `file_changes`
- `validation_runs`

Current behavior:

- `WorkProvenanceStore.append(_:)` wraps event insert and projection upserts in one immediate transaction.
- `rebuildProjections()` clears projection tables and replays events.
- `pruneExpiredObservedHistory()` prunes high-volume observed worktree history while preserving semantic events.
- Store queries expose repositories, worktrees, session trees, external identities, file explanations, and events.

Extraction impact:

- The database schema should remain internal to the engine after extraction.
- Existing bmux data will need a migration/import path into the engine-owned storage location.
- bmux should stop constructing SQL queries against these tables directly once an API exists.

### ProvenanceObservability.sqlite

Current standard path:

```text
~/.local/state/bmux/work-provenance/ProvenanceObservability.sqlite
```

Schema version: `3`.

Tables:

- `pipeline_runs`
- `pipeline_stage_executions`
- `identity_resolution_attempts`
- `projection_lineage`

Current behavior:

- `ProvenanceObservabilityStore.record(...)` writes bounded lifecycle-ingestion traces.
- Observability is best-effort from `WorkProvenanceSubsessionLifecycleRecorder` unless tests request awaited writes.
- Current O1/O2/O3 coverage is limited to `AgentSubsessionLifecycleChange -> WorkProvenance event append -> projection update`.

Extraction impact:

- Observability is operational telemetry, not authoritative engineering history.
- It can move with the engine daemon, but engine contracts must keep it separate from authoritative provenance APIs.

### BmuxContextEfficiency.sqlite

Current standard path:

```text
~/.local/state/bmux/context-efficiency/bmux-context-efficiency.sqlite
```

Schema version: `1`.

Tables:

- `schema_migrations`
- `import_sources`
- `import_cursors`
- `evidence_artifacts`
- `agent_threads`
- `rollout_events`
- `parser_errors`
- `token_telemetry_events`
- `model_calls`
- `tool_calls`
- `tool_outputs`

Current behavior:

- `ContextEfficiencyStore.importRollout(...)` stream-parses Codex rollout JSONL incrementally.
- It stores compact facts plus source offsets and does not copy raw rollout payloads into SQLite.
- It remains read-only telemetry/evidence import, not semantic provenance.

Extraction impact:

- The engine should not blindly absorb every context-efficiency table.
- The first integration should link evidence and agent-thread facts through stable external identities and evidence references.

## Capture Paths

### Git Worktree Observation

Path:

```text
Workspace changes/current-directory notifications
-> TabManager.workspaceTabsWillChange(to:)
-> WorkProvenanceRuntime.observeWorkspaces(...)
-> WorkProvenanceObservationService.observeWorkspaceSnapshots(...)
-> WorkProvenanceGitInspector.snapshot(...)
-> WorkProvenanceStore.append(worktreeObserved event)
```

Reusable facts:

- repository root
- common Git directory
- remote slug
- branch
- HEAD commit
- dirty state
- file status entries

bmux-owned pieces:

- workspace-change trigger
- workspace IDs/surface IDs/window ownership
- app startup wiring

### Subsession Lifecycle

Path:

```text
WorkstreamEvent subagentStart/subagentStop
-> AgentChatSessionRegistry.subsessionLifecycleChange(...)
-> AgentChatTranscriptService.handleSubsessionLifecycleChange(...)
-> AgentChatTranscriptService.recordSubsessionLifecycleChanges(with:)
-> WorkProvenanceRuntime.recordSubsessionLifecycleChange(...)
-> WorkProvenanceSubsessionLifecycleRecorder.record(...)
-> WorkProvenanceStore.appendWithStageTrace(...)
-> ProvenanceObservabilityStore.record(...)
```

Reusable facts:

- parent session ID
- child session identity category
- child session record
- session relationship
- external identity
- lifecycle event ID
- identity-resolution trace
- projection-lineage trace

bmux-owned pieces:

- `AgentSubsessionLifecycleChange`
- hook event parsing
- `AgentChatSessionRegistry`
- workspace/surface/display-name metadata

### Codex Telemetry Import

Path:

```text
bmux context-efficiency import
-> CodexStateMetadataReader.threadMetadata(...)
-> ContextEfficiencyStore.importRollout(...)
-> CodexRolloutJSONLStreamReader
-> CodexRolloutTelemetryParser
-> BmuxContextEfficiency SQLite facts
```

Reusable facts:

- model calls
- token telemetry
- tool calls
- tool outputs
- parser errors
- source references and offsets
- command execution candidates in derived reports

Current boundary:

- This is already package-local and public.
- It is still a bmux-named package and bmux CLI command surface, not an independent engine API.

## UI And CLI Consumers

### CLI Consumers

Current provenance CLI commands:

- `bmux provenance explain`
- `bmux provenance context current`
- `bmux provenance worktrees list`
- `bmux provenance sessions tree`
- `bmux provenance traces lifecycle-ingestion`

Current direct-storage readers:

- `CLIProvenanceSQLiteReader`
- `CLIProvenanceObservabilitySQLiteReader`

Extraction risk:

- These readers know table names, column names, recursive CTEs, and bmux storage paths.
- ADR-001 explicitly says consumers must never manipulate provenance database tables directly. These readers must be replaced by SDK/API calls during Phase 4.

### UI Consumers

No dedicated provenance UI was found in this audit slice. Current UI interaction is indirect:

- bmux startup creates and starts `WorkProvenanceRuntime` in `Sources/bmuxApp.swift`.
- `TabManager` forwards workspace list changes into the runtime.
- `AgentChatTranscriptService` forwards subsession lifecycle changes into the runtime.

Future visualization remains a bmux responsibility, but the UI should consume engine APIs rather than engine tables.

## Shared Types And bmux Assumptions

Portable current types:

- Most `WorkProvenance*Record` DTOs are plain `Codable`, `Equatable`, `Sendable` values.
- `WorkProvenanceEvent`, payload, source, confidence, retention policy, and stable ID helpers are close to engine-contract shape.
- `Provenance*Record` observability DTOs are plain values and can move after contracts are named.

Current bmux assumptions to terminate at adapters:

- Storage defaults include `bmux` and `work-provenance` path names.
- Session records carry `workspace_id`, `surface_id`, and `agent_kind` strings derived from bmux runtime state.
- Git observation is triggered by `Workspace` and `TabManager` changes.
- Subsession lifecycle input is the app-local `AgentSubsessionLifecycleChange` type.
- CLI provenance readers open local SQLite databases directly.
- Python CLI tests create raw provenance tables directly instead of going through an API fixture.

## Tests

Existing coverage:

- `bmuxTests/WorkProvenanceStoreTests.swift`
  - append/replay/file explanation
  - pruning
  - legacy payload decoding
  - session relationship/external identity replay
- `bmuxTests/WorkProvenanceObserverTests.swift`
  - Git observation behavior and duplicate suppression
- `bmuxTests/SubsessionProvenanceTests.swift`
  - subsession start/stop session-tree persistence
  - O1 lifecycle-ingestion traces
  - O2 identity-resolution traces
  - O3 projection-lineage traces
  - trace filtering
- `tests/test_provenance_cli.py`
  - CLI session-tree and lifecycle trace output using hand-created SQLite fixtures
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/`
  - rollout stream reader
  - rollout telemetry parser
  - Codex state metadata reader
  - context-efficiency store behavior
- `tests/test_context_efficiency_cli.py`
  - context-efficiency CLI regressions

Testing gaps for extraction:

- No contract tests define the future public provenance API.
- No daemon/client integration test exists.
- No migration test imports existing bmux provenance databases into engine storage.
- CLI tests currently validate table shape rather than API behavior.
- App-target `bmuxTests` compile the app; a future engine package needs standalone tests that do not launch AppKit or depend on bmux targets.

## What Can Be Reused

- Append-only event plus projection architecture.
- Current domain DTOs as starting vocabulary.
- SQLite migration and transaction patterns.
- Stable deterministic ID/fingerprint approach.
- Store actor shape for local transactional writes.
- Projection rebuild behavior.
- Source/confidence fields and fact-vs-inference discipline.
- Context-efficiency source references and raw-evidence side-channel pattern.
- Observability pipeline/stage/identity/lineage records, as separate operational telemetry.

## What Should Be Replaced Or Reshaped

- Replace direct CLI SQLite readers with SDK/API calls.
- Replace bmux-owned storage paths in extracted code with engine-owned storage configuration.
- Split `WorkProvenanceRuntime` into bmux adapter code plus engine client calls.
- Split `WorkProvenanceSubsessionLifecycleRecorder` into:
  - bmux adapter: translate `AgentSubsessionLifecycleChange` into normalized engine requests;
  - engine logic: deterministic session/event/relationship/external identity append.
- Move store/domain code out of the app target only after public contracts are introduced.
- Convert current app-target tests into engine package contract/unit tests plus bmux adapter tests.
- Stop treating SQLite table shape as a public test fixture for CLI behavior.

## Important Coupling Risks

- `WorkProvenanceStore` is app-target-internal today. Moving it directly would force broad access-control and project wiring changes without a stable API boundary.
- The current lifecycle recorder reaches into the store to query a parent session during event construction. In engine form, this should be an engine operation or a contract-backed query, not adapter SQL.
- `WorkProvenanceObservationService` mixes capture cadence, Git inspection, ID construction, and event construction. Extraction should separate capture from normalized append.
- `ProvenanceObservabilityStore` reuses `WorkProvenanceSQLiteDatabase`. That is fine internally, but the public engine boundary should not expose database helpers.
- CLI and Python tests already depend on table names. Leaving that dependency in place will make database schema internalization difficult later.
- `ContextEfficiencyStore` and `WorkProvenanceStore` are separate stores with overlapping session/thread concepts. Merging them now would violate the current roadmap; link through identities first.

## Unknowns Requiring Experiments

- Whether the independent engine should be Swift-first, TypeScript-first, or dual-package in V1. ADR-001 suggests TypeScript SDK, but the reusable implementation is currently Swift.
- Whether the local daemon should own all writes immediately, or whether the first SDK can be in-process while preserving daemon-compatible contracts.
- How existing `bmux-work-provenance.sqlite` should be migrated into an engine-owned path without losing user data.
- How to represent bmux workspace/surface IDs in engine contracts without making them first-class engine concepts.
- Which current query surfaces should be first contract tests: session tree, file explanation, worktree list, lifecycle trace, or append event.
- Whether `ProvenanceObservability.sqlite` moves into the engine repo in the same phase as authoritative provenance storage or later.

## Proposed Change Map

### Phase 1: Characterize Behavior

Goal: lock current behavior before interfaces move.

Actions:

1. Add contract-style tests around the current `WorkProvenanceStore` API for append, replay, session tree, file explanation, and idempotent lifecycle ingestion.
2. Add explicit tests documenting which `WorkProvenanceEventPayload` fields are semantic domain facts versus bmux adapter metadata.
3. Add CLI fixture tests that use store APIs to create data instead of hand-writing SQLite tables, where feasible.

### Phase 2: Introduce Public Contracts In bmux

Goal: create the boundary before extraction.

Actions:

1. Define a narrow local protocol/API surface for:
   - append event
   - append lifecycle event
   - query session tree
   - query file explanation
   - query worktrees
   - query lifecycle traces
2. Move bmux runtime code to call the protocol rather than concrete `WorkProvenanceStore` where possible.
3. Create normalized request/response DTOs that do not import `TabManager`, `Workspace`, or `AgentSubsessionLifecycleChange`.

### Phase 3: Create Engine Repository Skeleton

Goal: independent product shell without changing bmux behavior.

Actions:

1. Create the engine repo with `packages/core`, `packages/contracts`, `packages/storage-sqlite`, `apps/daemon`, and `apps/cli` or the closest final structure after the Swift/TypeScript implementation decision.
2. Move portable DTOs and storage logic behind the contracts.
3. Keep database schema internal and cover it through contract tests.

### Phase 4: Reconnect bmux As First Client

Goal: remove bmux direct storage dependency.

Actions:

1. Replace `CLIProvenanceSQLiteReader` and `CLIProvenanceObservabilitySQLiteReader` with engine SDK/API clients.
2. Replace `WorkProvenanceRuntime.live()` store construction with engine client construction and graceful degradation on daemon/client failure.
3. Keep Git/workspace/subsession translation in bmux adapters.

### Phase 5: Data Migration

Goal: preserve existing users' local provenance history.

Actions:

1. Implement an idempotent migration from current bmux SQLite paths to engine storage.
2. Validate event count, projection rebuild, session tree output, and file explanation output before and after migration.
3. Keep a development rollback path until the migration is proven.

## First Safe Implementation Target

The next code slice should not create the engine repo yet. The safest next slice is Phase 1 behavior characterization plus a small contract draft in bmux:

1. Add a `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md` or equivalent plan that names the minimum API and DTOs.
2. Add or adjust tests so session-tree and file-explanation behavior can be asserted without relying on CLI table fixtures.
3. Only then introduce the first protocol/contract layer around the current store.

This avoids a repository split before behavior and API boundaries are stable.

## Phase 0 Conclusion

The extraction should center on the existing `WorkProvenance` event/projection model. bmux should retain capture adapters, UI, workspace/session orchestration, and visualization. The first hard boundary to remove is direct SQLite table access from bmux CLI diagnostics. The second hard boundary is app-model coupling in `WorkProvenanceRuntime`, workspace snapshots, and subsession lifecycle recording.

Do not move files into a new repository until the public API contracts and behavior tests exist in bmux.
