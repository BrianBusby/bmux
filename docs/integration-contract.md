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

Rollback should be a scoped Git revert in the adopter repository that removes the package dependency and restores the previous local read path.

Appender note: set `ProvenanceEvent.evidenceOrigin` and `ProvenanceEvent.evidenceScope` when the producing system or ownership boundary is known. Existing V1 adopters may leave both fields unset. `ProvenanceSource` remains the claim classification, not the origin system.
