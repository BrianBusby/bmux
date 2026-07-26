# Provenance Engine Adoption

Status: Slice E V1 consumer adoption implemented locally. bmux now uses the finalized Provenance Engine V1 public contract for adopted read and write paths.

Engine revision: `7ed4450410f344f01472ba62f534a04c6c0d2774` from `git@github.com:BrianBusby/provenance-engine.git`.

Planning authority: this is the bmux-local adoption inventory and implementation state. The canonical cross-repository roadmap is `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

## Current State

The Xcode project links the public products `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. Adopted bmux paths construct clients with `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and do not import implementation targets such as `ProvenanceEngineSQLite`.

Adopted read paths:

- `bmux provenance worktrees list` calls `client.worktrees(...)`.
- `bmux provenance sessions tree <session-id>` calls `client.sessionTree(...)`.
- `bmux provenance explain <path>` calls `client.fileExplanation(...)`.
- `bmux provenance context current` calls `client.currentContext(...)`.

Adopted write paths:

- Agent lifecycle recording calls `client.recordSessionLifecycle(...)` with `ProvenanceSessionLifecycleRequest`.
- Worktree observation capture calls `client.appendEvent(...)` with public `ProvenanceEvent` contracts.

bmux still owns CLI parsing, Git path resolution, fallback behavior, output compatibility, UI/workspace orchestration, capture scheduling, duplicate-observation policy, and presentation. Provenance Engine owns immutable evidence, deterministic Current State, provenance interpretation, and bounded provenance queries.

## Slice E Completion

Current-context migration: `bmux provenance context current` now resolves the bmux Git target, constructs the public SDK client, and calls `currentContext(...)`. CLI output behavior is preserved through bmux-owned adapters in `CLIProvenanceContext`.

Lifecycle migration: production lifecycle capture now records through `recordSessionLifecycle(...)`. The old bmux-local child-session compatibility seam and recorder were removed from the app target. Event names in bmux lifecycle events now use `session_started` and `session_stopped`.

Capture migration: `WorkProvenanceObservationService` now appends observable worktree facts through public `appendEvent(...)`. Git inspection, snapshot deduplication, and best-effort runtime degradation remain bmux-owned producer responsibilities.

Test fixtures: session tree, file explanation, and current context CLI fixtures seed provenance databases through public engine SDK packages rather than direct projection inserts for adopted paths.

## Reference Consumer Pattern

A future producer can follow bmux without inspecting engine internals:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK

let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
    try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)

_ = await client.recordSessionLifecycle(ProvenanceSessionLifecycleRequest(
    phase: .started,
    parentSessionID: parentSessionID,
    agentKind: "codex",
    workspaceID: workspaceID,
    surfaceID: surfaceID,
    workingDirectory: workingDirectory,
    externalIdentityKind: "subagent",
    externalIdentityValue: externalSessionID,
    displayName: displayName,
    timestamp: Date()
))

_ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: repositoryPath))
```

## Remaining Local Surface

The following bmux-local files intentionally remain for historical compatibility, tests, or observability presentation:

- `WorkProvenanceStore` and local SQLite helpers still exist as legacy storage support.
- `BmuxLegacyProvenanceClient` still exists for legacy tests and transitional code auditability.
- `CLIProvenanceObservabilitySQLiteReader` still backs `bmux provenance traces lifecycle-ingestion` because V1 does not define an external observability trace API.
- Historical docs in `provenance-engine-adoption-history.md` still mention previous subsession terminology as slice history.

Do not add new provenance consumer behavior to those local surfaces. New reads and writes should use the public engine client.

## Architectural Findings

- The V1 public Current State APIs are sufficient for bmux's current worktree, session tree, file explanation, and current-context CLI behavior.
- The producer-neutral lifecycle API is sufficient for bmux agent lifecycle capture.
- bmux can record observable Git/worktree facts through `appendEvent(...)` without depending on engine projections.
- Presentation stays in bmux; meaning and deterministic state stay in Provenance Engine.
- Remaining local storage code is legacy/supporting surface, not the adopted source of truth for new provenance consumer behavior.

## Validation Notes

Slice E local validation is recorded in `docs/context-efficiency/current-status.md` and the final handoff report for the implementation turn.
