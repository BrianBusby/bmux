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

Rollback should be a scoped Git revert in the adopter repository that removes the package dependency and restores the previous local read path.

Appender note: set `ProvenanceEvent.evidenceOrigin` and `ProvenanceEvent.evidenceScope` when the producing system or ownership boundary is known. Existing V1 adopters may leave both fields unset. `ProvenanceSource` remains the claim classification, not the origin system.
