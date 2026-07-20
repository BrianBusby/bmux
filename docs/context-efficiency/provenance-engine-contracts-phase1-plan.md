# Provenance Engine Extraction: Phase 1 Contract Plan

Status: drafted on 2026-07-20 for ADR-001 Phase 1.

Inputs:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`

## Purpose

Phase 1 characterizes current `WorkProvenance` behavior and names the smallest public contract surface needed before moving implementation into an independent Provenance Engine.

This phase still runs inside bmux. It should not create the independent repository, add a daemon, move storage, or replace runtime wiring yet.

## Phase 1 Outcomes

Phase 1 is complete when:

- Current event/projection behavior is covered by contract-style tests.
- The future public API boundary is named without importing bmux app models.
- bmux adapter inputs are separated from engine-owned requests in documentation.
- Direct SQLite consumers are identified as compatibility debt to remove in Phase 4.

## Behavior Invariants To Preserve

### Event Ledger

- Appending an event inserts exactly one immutable event row.
- Duplicate event IDs fail the append and do not mutate projections.
- Events remain readable in append order after reopening the store.
- Historical payload JSON remains decodable when newer optional fields are absent.

### Projections

- Projections are rebuildable from the event ledger.
- Rebuilt projections match the observable query results before rebuild.
- Current-state projections use upsert semantics for repositories, worktrees, sessions, relationships, identities, work items, contributions, checkpoints, change sets, file changes, and validations.
- File explanation queries return compact graph context without loading raw evidence.

### Session Trees

- Child session relationships preserve parent, root, depth, source, confidence, and timestamps.
- Session trees include the root when the root session exists.
- External identities remain queryable by session and are unique by external system/kind/value.

### Subsession Lifecycle

- Identical lifecycle input and timestamp produce deterministic event, session, relationship, and external identity IDs.
- Native subsession IDs produce high-confidence identities.
- Missing native subsession IDs produce low-confidence stable fallback identities.
- Nested subsessions derive root and depth from the parent relationship.
- Stop-before-start creates a completed child session without a start timestamp.
- Start followed by stop preserves the original start timestamp and updates completion status.

### Observability

- Lifecycle ingestion traces are best-effort and separate from authoritative provenance.
- Successful lifecycle ingestion emits run, stage, identity-resolution, and projection-lineage rows.
- Failed duplicate lifecycle ingestion does not duplicate authoritative events and does not emit projection-lineage rows.
- Trace filters by run, parent session, child session, and status remain bounded.

## Minimum Engine Contract Surface

The first contract should be intentionally narrow. It should cover current behavior before adding new concepts such as decisions, findings, retrieval, or context bundles.

### Health And Capabilities

```swift
struct ProvenanceHealth: Codable, Equatable, Sendable {
    var status: String
    var version: String
    var capabilities: [String]
}
```

Required capabilities for the first bmux client:

- `append_event`
- `record_subsession_lifecycle`
- `query_session_tree`
- `query_file_explanation`
- `query_worktrees`
- `query_lifecycle_traces`

### Authoritative Write Requests

Initial write requests should not import `TabManager`, `Workspace`, `AgentSubsessionLifecycleChange`, or any SwiftUI/AppKit type.

```swift
struct ProvenanceAppendEventRequest: Codable, Equatable, Sendable {
    var event: WorkProvenanceEvent
}

struct ProvenanceSubsessionLifecycleRequest: Codable, Equatable, Sendable {
    var phase: String
    var parentSessionID: String
    var agentKind: String
    var workspaceID: String?
    var surfaceID: String?
    var workingDirectory: String?
    var externalIdentityKind: String?
    var externalIdentityValue: String?
    var displayName: String?
    var timestamp: Date
}
```

The bmux adapter maps `AgentSubsessionLifecycleChange` into `ProvenanceSubsessionLifecycleRequest`.

### Query Requests

```swift
struct ProvenanceSessionTreeRequest: Codable, Equatable, Sendable {
    var rootSessionID: String
    var limit: Int?
}

struct ProvenanceFileExplanationRequest: Codable, Equatable, Sendable {
    var worktreeID: String
    var path: String
}

struct ProvenanceWorktreeListRequest: Codable, Equatable, Sendable {
    var repositoryID: String?
    var limit: Int?
}

struct ProvenanceLifecycleTraceListRequest: Codable, Equatable, Sendable {
    var pipelineRunID: String?
    var parentSessionID: String?
    var childSessionID: String?
    var status: String?
    var limit: Int?
}
```

### Query Responses

Initial responses can mirror existing DTOs while preserving API ownership. The contract should avoid table-oriented row names and expose domain names instead:

- `ProvenanceSessionTreeResponse`
- `ProvenanceFileExplanationResponse`
- `ProvenanceWorktreeListResponse`
- `ProvenanceLifecycleTraceListResponse`

Each response should include:

- `schemaVersion`
- `found` or `status`
- bounded records
- optional bounded `reason`
- source/confidence where applicable

## bmux Adapter Boundary

bmux owns these translations:

- `Workspace` to repository/worktree observation request.
- `AgentSubsessionLifecycleChange` to normalized subsession lifecycle request.
- CLI flags and localized output to engine query requests.
- Future UI view models to engine query responses.

The engine owns these operations:

- deterministic ID generation for engine entities;
- event append and projection update transactions;
- projection rebuild;
- lifecycle event normalization once given a normalized request;
- authoritative query behavior;
- schema migrations;
- lifecycle ingestion observability records.

## Direct SQLite Debt

The following files currently read engine-candidate tables directly and should be treated as Phase 4 replacement targets:

- `CLI/CLIProvenanceSQLiteReader.swift`
- `CLI/CLIProvenanceObservabilitySQLiteReader.swift`
- direct SQLite fixtures in `tests/test_provenance_cli.py`

Phase 1 may keep these files unchanged, but new tests should prefer store/API setup where feasible so table shape stops becoming public behavior.

## First Implementation Slices After This Plan

1. Add or finish contract-style tests around existing store behavior.
2. Introduce internal protocol names that match the minimum contract surface without moving files.
3. Wrap `WorkProvenanceStore` behind those protocols inside bmux.
4. Convert one CLI path, likely `sessions tree`, to use the protocol-backed client in-process before any daemon work.

Do not start the independent repository until those contracts are exercised inside bmux.
