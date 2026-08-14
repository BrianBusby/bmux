# Provenance Engine Integration Contract

This document is the technical contract authority for adopters. It defines public integration contracts, not the full platform architecture or implementation roadmap. The complete platform north star is `docs/reference-architecture.md`; the current implementation boundaries are in `docs/architecture.md`; the coordinated bmux adoption sequence and cross-repository acceptance gates live in `docs/bmux-integration-roadmap.md`.

External adopters should import:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK
```

Create an in-process SQLite client through `ProvenanceEngineClientFactory`:

```swift
let client = try ProvenanceEngineClientFactory()
    .sqliteClient(databaseURL: databaseURL)
let response = try await client.worktrees(ProvenanceWorktreeListRequest())
```

For default engine-owned storage, use:

```swift
let client = try ProvenanceEngineClientFactory().defaultSQLiteClient()
```

Do not construct `ProvenanceSQLiteRepository` from adopter code. Do not read engine SQLite tables directly. Seed integration tests by appending public `ProvenanceEvent` values through `ProvenanceEngineClient.appendEvent`.

The accepted worktree read contract is:

- Request: `ProvenanceWorktreeListRequest(repositoryID:limit:)`
- Response: `ProvenanceWorktreeListResponse`
- Row: `ProvenanceWorktreeListEntry`
- Worktree DTO: `ProvenanceWorktreeRecord`
- Repository DTO: `ProvenanceRepositoryRecord`

The accepted session-tree read contract is:

- Request: `ProvenanceSessionTreeRequest(rootSessionID:limit:)`
- Response: `ProvenanceSessionTreeResponse`
- Root ID: `ProvenanceSessionTreeResponse.rootSessionID`
- Found flag: `ProvenanceSessionTreeResponse.found`
- Missing reason: `ProvenanceSessionTreeResponse.reason`, currently `no_session` when no root session projection is found
- Session DTO: `ProvenanceSessionRecord`
- Relationship DTO: `ProvenanceSessionRelationshipRecord`
- External identity DTO: `ProvenanceExternalIdentityRecord`

Session-tree responses return domain records in engine query order. Consumers own CLI, UI, JSON, and fallback presentation. Consumers must not read `provenance_sessions`, `provenance_session_relationships`, or `provenance_session_external_identities` directly.

`ProvenanceSessionTreeRequest.limit` is an engine row budget, not a presentation cap. The current SQLite-backed implementation applies the limit across the combined session and relationship rows needed for tree traversal. Returned relationships are coherent for returned child sessions: the engine does not keep a relationship row when the child session could not be included within the limit. External identities are then returned for the included sessions. Consumers that need a session-count-oriented product cap should adapt at their presentation or adapter boundary instead of treating the engine limit as that cap. If future consumers need independent session, relationship, or identity limits, add an explicit versioned request contract rather than overloading the current `limit`.

The accepted file-explanation read contract is:

- Request: `ProvenanceFileExplanationRequest(worktreeID:path:)`
- Response: `ProvenanceFileExplanationResponse`
- Found flag: `ProvenanceFileExplanationResponse.found`
- Missing reason: `ProvenanceFileExplanationResponse.reason`, currently `no_file` when no file-change projection matches the requested worktree and path
- Explanation DTO: `ProvenanceFileExplanation`
- File-change DTO: `ProvenanceFileChangeRecord`
- Linked DTOs, when available: `ProvenanceChangeSetRecord`, `ProvenanceCheckpointRecord`, `ProvenanceContributionRecord`, `ProvenanceSessionRecord`, `ProvenanceWorkItemRecord`, `ProvenanceWorktreeRecord`, and `ProvenanceRepositoryRecord`

File-explanation requests use V1 path identity: `worktreeID` identifies the Git worktree, and `path` is the normalized repository-relative path exactly as stored on `ProvenanceFileChangeRecord.path`. The engine does not resolve absolute paths, call Git, inspect the filesystem, expand symlinks, fold case, or infer repository roots for this request. Consumers that accept CLI or UI paths should resolve the Git worktree and normalize to repository-relative path before calling the engine.

For a matching `worktreeID` and `path`, the engine returns at most one explanation: the newest file-change projection for that exact path in that exact worktree. The current SQLite-backed implementation orders matching file changes by `updatedAt` descending with append-storage insertion order as a deterministic tie-breaker. There is no request limit because the V1 response is a single focused explanation, not a list. Consumers own JSON, text, fallback, and presentation compatibility.

When no file-change projection matches, the engine returns `found == false`, `reason == "no_file"`, and `explanation == nil`. Missing database, missing worktree, path outside a Git worktree, and user-facing fallback strings remain consumer responsibilities unless a future public contract explicitly moves those concerns into the engine.

Consumers must not read `provenance_file_changes`, `provenance_change_sets`, `provenance_checkpoints`, `provenance_work_contributions`, `provenance_sessions`, `provenance_work_items`, `provenance_worktrees`, or `provenance_repositories` directly for file explanations.

V1 path identity limitations: moved files are represented only by the current file-change records already appended by producers; no historical rename tracking is performed. Deleted files can be explained only when a producer appended a matching repository-relative path with a deletion-like status. Case sensitivity follows exact stored string equality. Symlink targets are not resolved by the engine. Historical identity across renames, copies, case-only renames, repository moves, or multiple checked-out paths is outside V1.

The Slice E-ready current-context read contract is:

- Request: `ProvenanceCurrentContextRequest(repositoryPath:activeSessionLimit:dirtyFileLimit:unattributedChangeLimit:recentCheckpointLimit:validationRunLimit:conflictLimit:)`
- Response: `ProvenanceCurrentContextResponse`
- Found flag: `ProvenanceCurrentContextResponse.found`
- Missing reason: `ProvenanceCurrentContextResponse.reason`, currently `no_worktree` when no worktree projection matches the requested repository path
- Worktree DTO: `ProvenanceWorktreeRecord`
- Repository DTO: `ProvenanceRepositoryRecord`, when available
- Active session row: `ProvenanceCurrentContextSession`
- Dirty and unattributed file rows: `ProvenanceCurrentContextFileChange`
- Checkpoint row: `ProvenanceCurrentContextCheckpoint`
- Validation-run row: `ProvenanceCurrentContextValidationRun`
- Conflict row: `ProvenanceCurrentContextConflict`

Current-context requests use V1 worktree path identity: `repositoryPath` is the absolute Git worktree root path already resolved by the consumer. The engine does not inspect `cwd`, shell out to Git, normalize repository paths, discover repository roots, or choose default limits from CLI policy. Consumers should resolve the current directory to a Git worktree root before calling the engine.

When a worktree projection exists for the requested path, the engine returns `found == true`, `reason == nil`, the matched worktree, the linked repository when present, and bounded sections. A known worktree with no recorded session, file, checkpoint, validation, or conflict activity is still a found response with empty section arrays. When no matching worktree projection exists, the engine returns `found == false`, `reason == "no_worktree"`, `worktree == nil`, `repository == nil`, and empty section arrays.

Current-context section semantics are domain query semantics, not presentation semantics:

- Active sessions include sessions for the worktree whose status is not terminal. Terminal statuses currently include complete/completed/finished/interrupted/cancelled/canceled/closed/stopped, matched case-insensitively. Linked active contributions and work items are included when available.
- Dirty files return the newest file-change projection per repository-relative path for the worktree, regardless of attribution source. This section reports recorded current file-change evidence; the consumer decides how to label or render dirty state.
- Unattributed changes are the subset of newest per-path file changes whose attribution source is `unattributed`.
- Recent checkpoints return checkpoint projections linked through contributions in the worktree.
- Validation runs return validation projections linked directly to a contribution or through a checkpoint contribution in the worktree.
- Conflicts report repository-relative paths touched by more than one active contribution in the worktree, with a count, a comma-separated contribution identifier list, and the latest update time for that path.

Current-context ordering is deterministic for the observable V1 behavior: active sessions are newest `updatedAt` first; dirty and unattributed file rows are newest file-change `updatedAt` first with append order as a tie-breaker; checkpoints are newest `createdAt` first with append order as a tie-breaker; validation runs are newest completion/start time first with append order as a tie-breaker; conflicts are newest path update first. Consumers should preserve or intentionally adapt the returned order at their presentation boundary instead of recreating engine SQL.

Each request limit is an independent engine row budget for its matching response section. Negative limits are treated as zero by the current SQLite-backed implementation. These limits are not bmux default CLI policy; bmux owns user defaults and any presentation caps.

Response guarantees: `schemaVersion == 1` for the current V1 shape; arrays are always present; linked records are optional where producers may have appended partial or unattributed evidence; no SQLite table names, row identifiers, SQL predicates, terminal rendering, JSON payload compatibility, fallback strings, or CLI errors are part of the public contract. Consumers must not read `provenance_worktrees`, `provenance_repositories`, `provenance_sessions`, `provenance_work_contributions`, `provenance_work_items`, `provenance_file_changes`, `provenance_change_sets`, `provenance_checkpoints`, or `provenance_validation_runs` directly for current context.

The accepted workspace-display Current State contract is:

- Write evidence: append a `ProvenanceEvent` with `eventType == .workspaceDisplayObserved` and `payload.workspaceDisplay`.
- Read request: `ProvenanceWorkspaceDisplayRequest(workspaceID:)`.
- Read response: `ProvenanceWorkspaceDisplayResponse`.
- Display DTO: `ProvenanceWorkspaceDisplayRecord`.
- Ticket DTO: `ProvenanceWorkspaceDisplayTicketLinkRecord`.
- Project DTO: `ProvenanceWorkspaceDisplayProjectLinkRecord`.
- Field provenance DTO: `ProvenanceWorkspaceDisplayFieldMetadataRecord`.

Workspace-display Current State is field-reconciled. It is not rebuilt as the
latest event payload. Absence of a field in a later accepted observation is not
evidence that the previously known field is false. Missing branch, ticket,
project, PR, current-work, or prompt values preserve prior accepted values until newer
evidence replaces them or an explicit clear establishes that they are no longer
pertinent.

Explicit clearing is represented by `ProvenanceWorkspaceDisplayRecord.clearedFields`.
Supported field clears include individual field names such as `branch`,
`current_work_summary`, and `last_submitted_prompt`, plus grouped work-item
clears such as `pull_request`, `tickets`, `ticket_ids`, `ticket_links`,
`projects`, and `project_links`.
Provider timeouts, lookup failures, incomplete producer payloads, app activation,
observer reconnect, telemetry events lacking a workspace-display field, session
compaction, and live session disappearance are not clear evidence.

The projection stores field-level provenance metadata for diagnostics and refresh
policy: field name, observed timestamp, source, evidence origin, evidence event
ID, evidence sequence, freshness, and explicit-clear state. Consumers are not
required to display that metadata, but diagnostics should use it to distinguish
current, stale, failed-refresh, explicitly-cleared, and unknown states.

`lastSubmittedPrompt` is a bounded workspace-display text fact supplied by the
consumer. It is not general transcript persistence. A consumer that needs raw
prompt or transcript storage must introduce a separate capture-policy contract
instead of expanding workspace-display state silently.

Rollback should be a scoped Git revert in the adopter repository that removes the package dependency and restores the previous local read path.

Appender note: set `ProvenanceEvent.evidenceOrigin` and `ProvenanceEvent.evidenceScope` when the producing system or ownership boundary is known. Existing V1 adopters may leave both fields unset. `ProvenanceSource` remains the claim classification, not the origin system.

## V1 Lifecycle Recording Contract

The canonical public lifecycle helper is now:

- Request: `ProvenanceSessionLifecycleRequest`
- Response: `ProvenanceSessionLifecycleResponse`
- Phase: `ProvenanceSessionLifecyclePhase`
- Method: `ProvenanceEngineClient.recordSessionLifecycle(...)`

This API is producer-neutral. A producer may provide an explicit `sessionID` for a root session, a `parentSessionID` when the session belongs to another session, or both when it already knows the source-domain identity and relationship. The engine records session lifecycle evidence and derives session relationship Current State when a parent is supplied.

Compatibility: `recordSubsessionLifecycle(...)`, `ProvenanceSubsessionLifecycleRequest`, `ProvenanceSubsessionLifecycleResponse`, `ProvenanceSubsessionLifecyclePhase`, and `ProvenanceEngineCapability.recordSubsessionLifecycle` remain temporarily available as deprecated compatibility wrappers for early adopters. New producers must use the session lifecycle names.

## V1 Local Durability Contract

A successful local SDK write is durable.

For `appendEvent(...)`, success means the event was committed to the local immutable ledger before `ProvenanceAppendEventResponse` was returned. For `recordSessionLifecycle(...)`, `accepted == true` means the lifecycle event was committed to the local immutable ledger before the response was returned.

The SQLite-backed implementation inserts the ledger event and applies deterministic Current State projection updates in one transaction. If the ledger insert, projection update, or commit fails, success is not returned. Duplicate event identifiers fail through the ledger uniqueness constraint and do not replace the accepted event or its projections.

This is an engine durability guarantee, not a producer delivery guarantee. Producers remain responsible for retrying calls that fail or never receive acknowledgement, and for any local outbox needed to survive producer crashes before the engine accepts an event.

## V1 Current State Contract

Current State is the canonical deterministic interpretation of engineering evidence. It is derived only from accepted evidence and deterministic engine rules, is rebuildable from the ledger, and powers worktrees, session trees, file explanations, and current context.

Producers own observing activity, assigning stable source/domain identities, emitting observable or declared facts, and retrying failed or unacknowledged delivery where needed.

Provenance Engine owns evidence validation, durable evidence storage, deterministic ordering and relationships, Current State derivation, projection rebuild, bounded provenance queries, and evidence attribution.

Consumers own presentation, UI, CLI formatting, local fallback policy, live Git probing when explicitly outside persisted provenance, and product-specific interaction behavior.
