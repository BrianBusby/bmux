# Bmux Provenance: Subsession and Delegation Integration

## Integrated Implementation Handoff

## 1. Objective

Extend the existing Bmux provenance system so Codex subsessions and delegated agent work become first-class, evidence-backed parts of the provenance graph.

The system must explain:

* why a child session was created
* which parent session initiated it
* what objective and constraints governed it
* what context or evidence the child received
* what the child actually did
* what files, commands, tests, commits, findings, or artifacts it produced
* whether the parent accepted, rejected, or superseded the result
* how much model context and compute the child consumed
* whether the delegation reduced parent-session context growth

This must extend the current Bmux provenance and context-efficiency architecture. Do not create a parallel "subagent manager" with duplicate sessions, work items, events, telemetry, or storage concepts.

---

## 2. Current Architecture That Must Be Preserved

Bmux currently has two related but separate persistence systems.

### 2.1 WorkProvenance

Location:

```text
Sources/WorkProvenance
```

Current responsibilities:

* append-only provenance event ledger
* current-state projections
* repository and worktree identity
* Git worktree observation
* dirty-file observation
* planned session, work-item, contribution, checkpoint, validation, and change-set entities
* read-only provenance CLI queries

Important existing components:

```text
WorkProvenanceStore
WorkProvenanceRuntime
WorkProvenanceObservationService
WorkProvenanceGitInspector
WorkProvenanceStableIDFactory
WorkProvenanceEvent
WorkProvenanceEventPayload
WorkProvenanceSessionRecord
WorkProvenanceWorkItemRecord
WorkProvenanceContributionRecord
WorkProvenanceCheckpointRecord
WorkProvenanceChangeSetRecord
WorkProvenanceFileChangeRecord
WorkProvenanceValidationRunRecord
```

Current database schema version:

```text
PRAGMA user_version = 2
```

The core architecture is:

```text
observed or declared fact
-> immutable WorkProvenanceEvent
-> WorkProvenanceStore.append()
-> current-state projections
-> CLI/UI/agent queries
```

Preserve this event-plus-projection model.

### 2.2 BmuxContextEfficiency

Location:

```text
Packages/macOS/BmuxContextEfficiency
```

Current responsibilities:

* read-only import of Codex rollout JSONL
* Codex state database metadata
* model-call records
* token telemetry
* tool-call and tool-output facts
* source byte-offset and line references
* parser diagnostics
* duplicate suppression
* command-execution candidates
* bounded CLI reports

Important existing components:

```text
ContextEfficiencyStore
ContextEfficiencySQLiteMigration
CodexRolloutTelemetryParser
CodexStateMetadataReader
ContextEfficiencyCommandAttributor
ContextEfficiencyWorkItemReferenceExtractor
```

This system currently owns imported Codex telemetry. It must remain read-only during the current roadmap phase.

Do not move delegation orchestration or lifecycle mutation into `BmuxContextEfficiency`.

### 2.3 Current Subsession Work

There is already app-side work in progress related to subsessions:

```text
AgentSubsessionLifecycleChange
AgentChatSessionRegistry+Lifecycle.swift
AgentChatTranscriptService
CLI/bmux.swift feed-hook enrichment
```

The current implementation reportedly:

* observes subagent start and stop
* creates ephemeral child workspaces
* marks child workspaces non-restorable
* captures scalar subagent metadata in feed-hook processing

These signals are not yet persisted into `WorkProvenance`.

Use this existing work as the first structured capture source.

Do not independently invent another subsession detector until these paths have been inspected.

---

## 3. Architectural Decisions

The following decisions are now part of this integration plan.

### 3.1 Delegation Is a First-Class Entity

Add a first-class `WorkProvenanceDelegationRecord`.

Do not model delegation solely as:

```text
parentSessionID
```

on a child session.

A parent-child session relationship explains topology but not:

* the delegated objective
* rationale
* input context
* permissions
* expected outputs
* completion requirements
* parent disposition

A delegation is a task contract and must be independently addressable.

### 3.2 Reuse Existing Session Entities

Do not create a separate `SubsessionRecord` representing the same logical execution context as `WorkProvenanceSessionRecord`.

Use:

```text
WorkProvenanceSessionRecord
```

for both root and child agent sessions.

Add relationship fields or relationship projections so a session can expose:

* parent session
* root session
* inbound delegation
* outbound delegations
* delegation depth

`ContextEfficiencyAgentThreadRecord` remains the telemetry representation of a Codex thread.

The two records must be linked, not merged blindly and not duplicated.

### 3.3 Reuse Work Items

A delegated objective should normally reference an existing `WorkProvenanceWorkItemRecord`.

A delegation may:

* contribute to the parent's existing work item
* reference a child work item when the delegated objective has its own durable lifecycle
* initially exist without a work item when the objective has not yet been classified

Do not create a second unrelated task model.

### 3.4 WorkProvenance Owns Delegation Semantics

Store delegation contracts, lifecycle, completion, and parent disposition in `WorkProvenance`.

Reasons:

* delegation is semantic work provenance
* it relates directly to sessions, work items, contributions, files, validations, and future commits
* `WorkProvenance` already uses append-only events and projections
* `BmuxContextEfficiency` is deliberately read-only and currently focused on imported model/tool telemetry

`BmuxContextEfficiency` should later supply observed child-thread facts and telemetry links to `WorkProvenance`, but it should not own the delegation contract.

### 3.5 Keep the Databases Separate Initially

Do not merge the two SQLite databases as part of the first subsession slice.

Instead, introduce stable cross-store identifiers:

```text
WorkProvenanceSessionRecord.externalThreadID
ContextEfficiencyAgentThreadRecord.id
```

or a separate identity-link projection.

The first implementation must prove the domain and event flow before reopening the unified-database question.

### 3.6 Observation Before Intervention

The first release is capture and query only.

Do not add:

* automatic delegation decisions
* automatic task decomposition
* lifecycle warnings
* handoff recommendations
* automatic model selection
* automatic prompt mutation
* automatic child worktree creation
* automatic merging
* quality scoring
* coordination UI

The current project roadmap explicitly prioritizes trustworthy observation before intervention.

### 3.7 Retrieval Builds on Provenance

Agent retrieval and knowledge projection are now integrated as a later roadmap track in:

```text
docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md
```

Retrieval must use this plan's session, delegation, work-item, contribution, completion-report, and parent-disposition records as authoritative semantic provenance. It must not create a parallel task model, child-session model, delegation model, evidence store, or telemetry store.

The dependency order is:

```text
subsession lifecycle persistence
-> session and delegation identity
-> delegation contracts and parent disposition
-> semantic records such as decisions and findings
-> derived knowledge projections
-> bounded context packages
```

Do not begin retrieval knowledge projections, FTS, context-package generation, semantic-search adapters, automatic prompt injection, or orchestration before lifecycle and semantic provenance prerequisites are implemented and the retrieval Phase R0 investigation report is complete.

---

## 4. Target Domain Model

### 4.1 Delegation Record

Add a projection similar to:

```swift
struct WorkProvenanceDelegationRecord: Codable, Sendable, Equatable {
    let id: String

    let parentSessionID: String
    let childSessionID: String?
    let rootSessionID: String

    let workItemID: String?
    let parentContributionID: String?
    let childContributionID: String?

    let role: WorkProvenanceDelegationRole
    let title: String
    let objective: String
    let rationale: String?

    let expectedOutputsJSON: String
    let inputReferencesJSON: String
    let permissionsJSON: String

    let promptTemplateID: String?
    let promptTemplateVersion: Int?

    let status: WorkProvenanceDelegationStatus

    let resultSummary: String?
    let unresolvedRisksJSON: String?
    let recommendedNextAction: String?
    let confidence: Double?

    let createdAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let updatedAt: Date
}
```

Adapt names and serialization to existing local conventions.

Avoid embedding large transcripts, raw tool output, diffs, or rollout payloads in this row.

### 4.2 Delegation Role

Use a closed Swift enum persisted as stable strings:

```swift
enum WorkProvenanceDelegationRole: String, Codable, Sendable {
    case research
    case implementation
    case testing
    case review
    case debugging
    case documentation
    case integration
    case other
}
```

### 4.3 Delegation Status

```swift
enum WorkProvenanceDelegationStatus: String, Codable, Sendable {
    case created
    case launchRequested
    case running
    case completed
    case partiallyCompleted
    case failed
    case cancelled
    case abandoned
    case unresolved
}
```

The existing schema uses string statuses broadly. For new delegation types, define closed enums in Swift while preserving stable persisted strings.

Do not perform a broad conversion of all existing status fields in this feature.

### 4.4 Expected Outputs

Use a structured Codable representation stored as JSON initially:

```swift
struct WorkProvenanceExpectedOutput: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case finding
        case codeChange
        case testResult
        case review
        case artifact
        case commit
        case documentation
        case other
    }

    let kind: Kind
    let description: String
    let isRequired: Bool
}
```

A normalized child table may be introduced later if querying individual expected outputs becomes important.

For the first implementation, bounded JSON is acceptable if it follows current project conventions and does not contain raw output.

### 4.5 Input References

Use or add a generalized provenance reference type:

```swift
enum WorkProvenanceReference: Codable, Sendable, Equatable {
    case session(id: String)
    case delegation(id: String)
    case workItem(id: String)
    case contribution(id: String)
    case file(path: String, revision: String?)
    case commit(hash: String)
    case artifact(id: String)
    case checkpoint(id: String)
    case changeSet(id: String)
    case validationRun(id: String)
    case contextEvidence(id: String)
    case rawOutput(reference: String)
}
```

Do not copy evidence into the contract when a stable reference exists.

### 4.6 Permissions

```swift
struct WorkProvenanceDelegationPermissions: Codable, Sendable, Equatable {
    let mayEdit: Bool
    let allowedPaths: [String]?
    let prohibitedPaths: [String]?
    let mayRunTests: Bool
    let mayCommit: Bool
}
```

In the observation-first phase, these are declared constraints, not necessarily enforced constraints.

If an observed child action appears to violate the contract, record a discrepancy. Do not block execution yet.

### 4.7 Session Relationships

Extend session projection capabilities so each session can expose:

```swift
struct WorkProvenanceSessionRelationships: Codable, Sendable {
    let parentSessionID: String?
    let rootSessionID: String
    let inboundDelegationID: String?
    let outboundDelegationIDs: [String]
    let depth: Int
}
```

Do not denormalize outbound IDs into the `sessions` row unless that matches existing patterns.

A dedicated delegation table plus indexed queries is likely cleaner.

### 4.8 Completion Report

Add a bounded completion-report representation:

```swift
struct WorkProvenanceDelegationCompletionReport: Codable, Sendable, Equatable {
    enum Outcome: String, Codable, Sendable {
        case completed
        case partial
        case failed
    }

    let delegationID: String
    let childSessionID: String
    let outcome: Outcome
    let summary: String

    let fileReferences: [WorkProvenanceReference]
    let commandReferences: [WorkProvenanceReference]
    let validationReferences: [WorkProvenanceReference]
    let commitReferences: [WorkProvenanceReference]
    let artifactReferences: [WorkProvenanceReference]
    let findingReferences: [WorkProvenanceReference]

    let expectedOutputResults: [
        WorkProvenanceExpectedOutputResult
    ]

    let unresolvedRisks: [String]
    let recommendedNextAction: String?
    let confidence: Double?
}
```

This is a semantic report, not the source of truth for observed activity.

If a child claims a test passed but no validation evidence exists, preserve both facts and record the discrepancy.

### 4.9 Parent Integration

Add a first-class integration/disposition projection:

```swift
struct WorkProvenanceDelegationIntegrationRecord: Codable, Sendable, Equatable {
    enum Disposition: String, Codable, Sendable {
        case accepted
        case partiallyAccepted
        case rejected
        case superseded
        case needsFollowUp
    }

    let id: String
    let delegationID: String
    let parentSessionID: String
    let disposition: Disposition
    let summary: String

    let acceptedReferencesJSON: String
    let rejectedReferencesJSON: String
    let followUpDelegationIDsJSON: String

    let createdAt: Date
}
```

This distinction matters:

```text
child produced output
```

does not imply:

```text
parent accepted output
```

---

## 5. Event Model

Add event payloads and stable event-type strings for:

```text
delegation_created
delegation_launch_requested
delegation_child_discovered
delegation_child_linked
delegation_started
delegation_progressed
delegation_completed
delegation_partially_completed
delegation_failed
delegation_cancelled
delegation_result_received
delegation_result_accepted
delegation_result_partially_accepted
delegation_result_rejected
delegation_result_superseded
delegation_follow_up_created

subsession_started
subsession_stopped
subsession_interrupted
subsession_discovered
subsession_reconciled
```

Do not create duplicate events when one event can carry both lifecycle and relationship facts.

For example:

* `subsession_started` records the observed child lifecycle
* `delegation_child_linked` records that the observed child has been matched to a declared delegation

Each event should preserve existing fields where applicable:

```text
id
schema_version
event_type
timestamp
repository_id
worktree_id
session_id
contribution_id
source
confidence
payload_json
```

Add explicit parent, child, delegation, or work-item columns only when they materially improve indexing and are consistent with the current event ledger design.

Otherwise, retain them in versioned payloads and project them into indexed tables.

---

## 6. Sources and Confidence

Bmux already distinguishes observed facts, declarations, and inference. Preserve that distinction.

Suggested source categories:

```text
agentHook
codexRollout
codexState
agentSessionRegistry
userDeclared
agentDeclared
gitObservation
processObservation
reconciliation
inferred
```

Suggested confidence semantics:

```text
1.0       Explicit stable ID or authoritative structured event
0.9-0.99  Strong structured cross-source correlation
0.7-0.89  Multiple consistent metadata signals
0.5-0.69  Heuristic candidate
below 0.5 Unresolved or weak candidate
```

Do not silently convert a heuristic child match into a definitive parent-child relationship.

---

## 7. Identity Strategy

Identity is the highest-risk part of this feature.

Inspect and document all current identifiers:

```text
AgentChatSessionRecord.sessionID
Codex threads.id
ContextEfficiencyAgentThreadRecord.id
rollout filename UUID
hook session ID
app-server thread ID
workspace ID
surface ID
PID
subagent ID
subsession ID
request/tool-call ID
```

### 7.1 Canonical WorkProvenance Session ID

Continue using the existing `WorkProvenanceSessionRecord.id` as the canonical provenance-side session identity.

Do not change its meaning without a migration plan.

### 7.2 External Identity Links

Add an identity-link model if one does not already exist:

```swift
struct WorkProvenanceExternalIdentityRecord {
    let id: String
    let sessionID: String

    let system: String
    let kind: String
    let externalID: String

    let source: String
    let confidence: Double
    let createdAt: Date
    let updatedAt: Date
}
```

Example links:

```text
session A -> codex thread codex:<uuid>
session A -> agent-chat session <uuid>
session A -> workspace <uuid>
session A -> surface <uuid>
session B -> subagent native ID <id>
```

Use a uniqueness constraint over an appropriate tuple such as:

```text
system + kind + external_id
```

This avoids adding a new field to `sessions` for every evolving runtime identifier.

### 7.3 Root and Parent Relationships

Parent-child relationships should come from delegation and lifecycle evidence.

Do not infer them from terminal titles or file modification times when hook, process, surface, or native agent identity is available.

---

## 8. Capture Pipeline

### 8.1 First Authoritative Source

Inspect the in-progress app-side subsession code first:

```text
AgentSubsessionLifecycleChange
AgentChatSessionRegistry+Lifecycle.swift
AgentChatTranscriptService
CLI/bmux.swift
```

Determine:

* start event shape
* stop event shape
* available parent identifier
* available child identifier
* workspace/surface mapping
* agent kind
* cwd
* display name
* native subagent metadata
* whether the signal is idempotent
* whether events can arrive out of order
* whether child sessions survive app restarts
* whether an event can be replayed

Build the initial ingestion path around the strongest structured signal.

### 8.2 Initial Pipeline

Target flow:

```text
AgentSubsessionLifecycleChange
-> WorkProvenance lifecycle adapter
-> normalized WorkProvenanceEvent
-> WorkProvenanceStore.append()
-> sessions/delegations/identity-link projections
-> read-only CLI query
```

### 8.3 Codex Rollout Supplement

Separately investigate whether rollout JSONL exposes:

* subagent spawn
* subagent completion
* child thread ID
* tool call ID
* delegated prompt
* result-return event
* parent thread ID

If present:

```text
Codex rollout event
-> CodexRolloutTelemetryParser
-> ContextEfficiencyStore observed fact
-> cross-store reconciliation/linking service
-> WorkProvenance semantic event
```

Keep the importer read-only.

It may report an observed fact to a WorkProvenance integration layer, but it must not mutate Codex or initiate child sessions.

### 8.4 Explicit Delegation Creation

Eventually, the parent session or Bmux UI should create a delegation before the child starts.

For the initial read-only slice, support either:

1. observed child lifecycle without a pre-existing delegation, or
2. a declared delegation event supplied by existing hook metadata.

When an observed child has no known delegation, create:

```text
session relationship: known
delegation: unresolved or observed-only
```

Do not fabricate an objective.

A later parent declaration may enrich or reconcile that record.

---

## 9. Reconciliation

Add a reconciliation model for matching:

```text
declared delegation
<-> observed child session
<-> Codex thread
<-> agent-chat session
```

Suggested record:

```swift
struct WorkProvenanceDelegationReconciliationRecord {
    let id: String
    let delegationID: String
    let candidateChildSessionID: String
    let score: Double
    let method: String
    let evidenceJSON: String
    let status: String
    let createdAt: Date
    let resolvedAt: Date?
}
```

Methods may include:

```text
explicitDelegationID
nativeParentChildIdentity
hookSessionIdentity
processLineage
workspaceSurfaceIdentity
codexThreadIdentity
temporalMetadata
heuristic
```

Rules:

* explicit native identity wins
* strong structured mappings may auto-link
* ambiguous candidates remain unresolved
* low-confidence matches must not rewrite existing high-confidence links
* reconciliation must be idempotent
* all accepted and rejected matches remain auditable

---

## 10. Work Items and Contributions

Use existing entities as follows:

```text
Work item
└── Parent contribution
    └── Delegation
        └── Child contribution
            ├── checkpoints
            ├── change sets
            ├── file changes
            └── validation runs
```

A child session that performs analysis but changes no files still has a valid contribution.

Its outputs may include:

* finding
* recommendation
* architecture report
* evidence reference
* risk assessment
* review result

Do not require a commit or dirty-file change for a contribution to be meaningful.

---

## 11. Commands, Files, Tests, and Commits

### 11.1 Commands

Phase 3 command execution candidates currently exist in `BmuxContextEfficiency`.

Do not duplicate command parsing in `WorkProvenance`.

Create links from a child session or contribution to context-efficiency command records through stable IDs or cross-store reference records.

Preserve command attribution confidence:

```text
exact call ID
structured temporal association
candidate
unknown
```

### 11.2 File Changes

Current Git observation records:

```text
this path is dirty in this worktree
```

It does not prove:

```text
this child session changed this path
```

When a child session is active in a worktree, do not automatically assign all dirty files to it.

Attribution should require stronger evidence such as:

* file-write tool call
* command execution tied to the child
* checkpoint before/after diff
* child-declared file list corroborated by Git state
* exclusive worktree ownership
* explicit contribution declaration

Record `attribution_source` and `attribution_confidence`.

### 11.3 Validation Runs

Reuse `validation_runs`.

Associate validation with the child contribution or checkpoint.

Later, a context-efficiency command candidate may support the validation record, but command text alone should not prove test success.

### 11.4 Commits

There is no first-class commit table currently.

Add one before claiming complete child-to-commit provenance.

Suggested record:

```swift
struct WorkProvenanceCommitRecord {
    let id: String
    let repositoryID: String
    let worktreeID: String?
    let hash: String
    let parentHashesJSON: String
    let authorTimestamp: Date?
    let subject: String?
    let observedAt: Date
}
```

Add a contribution/commit relationship or production event.

Do not attempt full Git-history modeling in the first lifecycle slice.

Commit entity work belongs in a later integration phase after lifecycle capture is stable.

---

## 12. Prompt Contracts

Version prompt templates, but do not silently inject them in the first implementation.

### Parent Template

```text
Operate as the parent orchestration session.

Keep this session focused on:
- maintaining the overall objective
- decomposing work
- delegating bounded tasks
- integrating returned results
- making cross-task decisions

For every delegated task:
- define one objective
- state why it is delegated
- provide only the required context
- state whether edits are allowed
- identify allowed or prohibited paths when relevant
- specify validation requirements
- specify expected outputs
- include the Bmux delegation identifier

Do not paste full child transcripts into this session.
Return concise reports and provenance references.
```

### Child Template

```text
You are a child session working under a Bmux delegation.

Complete only the delegated objective.

Respect:
- editing permissions
- path scope
- validation requirements
- expected outputs

Do not make unrelated changes.

Return:
1. outcome
2. concise summary
3. files inspected
4. files changed
5. commands run
6. tests or validation run
7. commits or artifacts produced
8. unresolved risks
9. recommended next action
10. confidence
```

Store:

```text
template ID
template version
actual rendered prompt hash
retention level
```

Do not store sensitive full prompts by default if existing privacy configuration indicates summary-only or metadata-only retention.

---

## 13. Privacy and Raw Evidence

Preserve the current rule:

```text
Raw evidence is recoverable but not stored in hot SQLite rows.
```

Use:

```text
ChatRawTerminalOutputFileStore
rawOutputRef
ContextEfficiency evidence_artifacts
source path + byte offset + line number
```

Do not store:

* complete terminal transcripts
* complete rollout lines
* secrets
* environment dumps
* authentication tokens
* private keys
* large diffs

inside delegation projection rows or event payloads.

Add configurable prompt/report retention if needed:

```text
full
redacted
summaryOnly
metadataOnly
disabled
```

---

## 14. Query API

Add store-level queries before building a UI.

Minimum WorkProvenance queries:

```swift
func delegation(id: String) async throws -> WorkProvenanceDelegationRecord?
func delegations(
    filters: WorkProvenanceDelegationFilters
) async throws -> [WorkProvenanceDelegationRecord]

func parentSession(
    for childSessionID: String
) async throws -> WorkProvenanceSessionRecord?

func childSessions(
    for parentSessionID: String
) async throws -> [WorkProvenanceSessionRecord]

func sessionTree(
    rootSessionID: String
) async throws -> WorkProvenanceSessionTree

func delegationTimeline(
    delegationID: String
) async throws -> [WorkProvenanceEvent]

func delegationIntegration(
    delegationID: String
) async throws -> WorkProvenanceDelegationIntegrationRecord?

func unresolvedDelegationMatches()
    async throws -> [WorkProvenanceDelegationReconciliationRecord]
```

Add bounded CLI commands such as:

```bash
bmux provenance sessions tree <session-id> --json
bmux provenance delegations list --json
bmux provenance delegation show <delegation-id> --json
bmux provenance delegations unresolved --json
```

CLI output must:

* remain bounded
* avoid raw payload leakage
* expose source and confidence
* identify unresolved mappings
* include stable IDs for drilldown

---

## 15. Metrics and Context Efficiency

Delegation metrics belong in a later phase after lifecycle and identity are stable.

The schema should permit eventual linkage to:

```text
input tokens
cached input tokens
non-cached input tokens
output tokens
model calls
compactions
tool calls
elapsed time
files inspected
files changed
validations
commits
accepted outputs
follow-up delegations
```

Derived metrics may later include:

```text
cache-hit ratio
tokens per accepted output
delegation acceptance rate
rework rate
average child depth
parent context growth
parent context avoided
```

Do not create quality scores from token counts alone.

Preserve raw facts separately from derived interpretation.

---

## 16. Revised Implementation Phases

### Phase A: Investigation and Architecture Map

Before schema changes:

1. Inspect current `WorkProvenance` event and projection implementation.
2. Inspect the active context-efficiency worktree.
3. Inspect the dirty subsession lifecycle implementation.
4. Document all available parent/child identifiers.
5. Inspect actual Codex rollout and hook event shapes.
6. Decide the first authoritative lifecycle source.
7. Identify migration conventions and test patterns.
8. Produce a concise implementation map.

Required report:

```text
Relevant modules
Current data flow
Available identifiers
Authoritative lifecycle source
Fallback signals
Proposed schema changes
Migration strategy
First test fixture
```

Do not begin broad implementation before this report.

### Phase B: Read-Only Subsession Lifecycle Persistence

This is the first implementation slice.

Implement:

* session upsert for observed child sessions
* external identity links
* parent/root session relationship
* lifecycle event payloads
* idempotent start/stop ingestion
* source and confidence
* migration
* CLI tree query
* tests

Persist at minimum:

```text
parent session ID
child session ID
root session ID
agent kind
workspace ID
surface ID
cwd
display name
start timestamp
stop timestamp
lifecycle status
source
confidence
```

Do not require a formal delegation contract yet.

Acceptance criteria:

1. Existing parent session state remains unchanged.
2. Child start creates or updates one child session projection.
3. Replayed start events do not duplicate sessions.
4. Child stop updates status and timestamp.
5. A parent-child tree can be queried.
6. Unavailable identifiers are represented as unknown, not guessed.
7. Existing provenance tests remain green.

### Phase C: First-Class Delegation Contract

Implement:

* `delegations` projection table
* delegation event payloads
* role
* objective
* rationale
* permissions
* expected outputs
* input references
* optional child session
* optional work item
* optional contributions
* migration and indexes
* query APIs
* tests

A delegation may exist before a child session is known.

Acceptance criteria:

1. Parent can declare a delegation without a child.
2. Child can later be linked.
3. Existing observed child sessions can remain undelegated.
4. Contracts remain bounded and raw-output-safe.
5. Required fields are validated.
6. Lifecycle transitions are tested.

### Phase D: Reconciliation

Implement:

* explicit ID reconciliation
* native parent-child reconciliation
* identity-link reconciliation
* confidence-scored fallback matching
* ambiguous match records
* accepted/rejected reconciliation events
* CLI unresolved view
* tests

Do not auto-link low-confidence candidates.

### Phase E: Contributions and Child Reports

Implement:

* child contribution creation/linking
* completion report
* expected-output evaluation
* unresolved risks
* result references
* report discrepancy recording
* parent integration disposition
* follow-up delegation links
* tests

Do not treat self-reported output as equivalent to observed provenance.

### Phase F: Context-Efficiency Linkage

After the active Phase 3 telemetry work stabilizes:

* link `ContextEfficiencyAgentThreadRecord` to provenance sessions
* link model calls and token telemetry to child sessions
* link command candidates to contributions
* link work-item references to work items or delegation inputs
* preserve source offsets and parser evidence
* avoid copying telemetry rows into WorkProvenance unnecessarily

Prefer stable cross-store references or a read model over duplicated data.

### Phase G: Files, Validation, and Commits

Progressively improve:

* child-to-file attribution
* validation-run capture
* checkpoint support
* first-class commit records
* commit-to-contribution linkage
* rebase/squash reconciliation
* missing-worktree handling

Do not overclaim attribution.

### Phase H: UI

Build only after the data model and confidence signals are reliable.

Initial UI:

```text
Session/delegation tree
+ detail panel
+ unresolved-mapping warnings
+ source/confidence display
```

Display:

* title/objective
* role
* status
* model when linked
* elapsed time
* token summary when linked
* file count
* validation state
* commit count
* risk count
* parent disposition

Do not begin with a force-directed graph.

### Phase I: Lifecycle and Handoff Policy

Only after read-only evidence is measurable:

* context pressure warnings
* suggested delegation boundaries
* handoff recommendations
* bounded context packages
* prompt-template injection
* assisted child launch

This remains outside the initial integration.

---

## 17. Database Changes

Inspect current schema conventions before finalizing exact SQL.

Likely new WorkProvenance tables:

```text
delegations
delegation_integrations
delegation_reconciliations
session_external_identities
```

Potential later tables:

```text
commits
session_commit_links
contribution_command_links
context_evidence_links
```

Likely indexes:

```text
delegations_parent_session_idx
delegations_child_session_idx
delegations_root_session_idx
delegations_work_item_idx
delegations_status_created_idx
delegations_role_created_idx

external_identities_external_idx
external_identities_session_idx

reconciliations_delegation_idx
reconciliations_candidate_child_idx
reconciliations_status_score_idx

integrations_delegation_idx
integrations_parent_session_idx
```

Do not add every future table in the first migration.

Use incremental migrations matching the current project's migration and test practices.

---

## 18. Testing Requirements

### Lifecycle Tests

Cover:

* child start
* duplicate child start
* child stop
* stop before start
* missing parent
* missing child native ID
* root session calculation
* nested subsessions
* app restart/replay
* parent session remains unchanged
* unresolved external identity

### Delegation Tests

Cover:

* delegation without child
* child linked later
* child already observed before delegation
* multiple child candidates
* invalid lifecycle transition
* cancelled delegation
* partial completion
* child with no code changes
* research-only child
* failed child
* parent rejection
* follow-up delegation

### Reconciliation Tests

Cover:

* explicit delegation ID
* exact native parent-child identity
* matching Codex thread identity
* competing candidates
* low-confidence candidate
* prior high-confidence link
* replay idempotency
* rejected match remains auditable

### Store Tests

Cover:

* migration from current schema
* projection replay
* append idempotency
* pruning behavior
* query bounds
* source/confidence persistence
* no raw-output leakage
* large nested tree loading without N+1 queries

### Context-Efficiency Integration Tests

Cover later:

* child thread telemetry link
* model-call aggregation
* command-candidate link
* missing telemetry store
* stale telemetry
* duplicate cumulative telemetry
* source-reference preservation

---

## 19. Failure and Uncertainty Handling

Represent these explicitly:

* child lifecycle observed but parent unknown
* parent known but child native ID unavailable
* child never produces completion report
* child report malformed
* child claims changes not observed
* child claims validation not evidenced
* child performs unrelated work
* child exceeds declared path scope
* parent exits before child finishes
* parent rejects child output
* multiple children match one delegation
* one child matches multiple delegations
* worktree disappears
* branch rebased
* commits squashed
* rollout logs unavailable
* app lifecycle events missing
* telemetry store unavailable

Do not delete incomplete or contradictory evidence.

Use:

```text
status
source
confidence
discrepancy
missing evidence
reconciliation state
```

to represent uncertainty.

---

## 20. Non-Goals for the Initial Release

Do not include:

* autonomous task decomposition
* autonomous child launch
* model-selection policy
* prompt evolution
* automatic enforcement of permissions
* automatic branch or worktree creation
* automatic merge
* automatic lifecycle warnings
* automatic handoff
* adaptive learning
* distributed workers
* cross-repository scheduling
* complicated graph visualization
* broad database unification
* broad rewrite of existing status types
* live PTY interception unless separately approved

---

## 21. Final Acceptance Criteria

The integrated feature is complete through the initial meaningful release when:

1. Bmux persists observed parent-child session lifecycle in `WorkProvenance`.
2. Lifecycle ingestion uses existing structured app-side signals where available.
3. Parent, child, and root session relationships are queryable.
4. Replayed events are idempotent.
5. Delegation exists as a first-class task contract.
6. A delegation can exist before the child is known.
7. A child can later be reconciled to the delegation.
8. Ambiguous matches remain visible and unresolved.
9. Child sessions reuse existing session and work-item concepts.
10. Child work can link to contributions, files, validations, and future commits.
11. Child completion reports remain distinct from observed evidence.
12. Parent acceptance or rejection is persisted.
13. Existing WorkProvenance data remains backward compatible.
14. `BmuxContextEfficiency` remains read-only.
15. Context-efficiency telemetry can later link through stable identities.
16. CLI queries expose trees, delegation detail, and unresolved mappings.
17. Raw rollout and terminal output remain outside hot SQLite rows.
18. Unit, migration, integration, and replay tests pass.
19. Documentation explains identity, event flow, confidence, and store ownership.
20. No lifecycle policy or automated intervention is introduced prematurely.

---

## 22. Required Deliverables

Produce:

* initial architecture investigation report
* confirmed identifier map
* event-flow diagram
* schema migration
* delegation and relationship domain types
* WorkProvenance event payloads
* lifecycle ingestion adapter
* identity-link projection
* delegation projection
* reconciliation support
* query APIs
* bounded CLI commands
* fixtures for root, research, implementation, and review sessions
* migration tests
* lifecycle tests
* reconciliation tests
* developer documentation
* final implementation report

The final report must contain:

1. architecture implemented
2. authoritative lifecycle source used
3. identifiers available and missing
4. files changed
5. migrations added
6. tests run
7. known attribution limitations
8. unresolved identity questions
9. current store ownership
10. recommended next implementation slice

---

## 23. Codex Working Instructions

Begin by reading:

```text
AGENTS.md
docs/context-efficiency/current-status.md
docs/context-efficiency/roadmap.md
docs/context-efficiency/domain-model.md
docs/context-efficiency/proposed-integration.md
Sources/WorkProvenance
Packages/macOS/BmuxContextEfficiency
AgentChatSessionRegistry+Lifecycle.swift
AgentChatTranscriptService
CLI/bmux.swift
```

Also inspect the active context-efficiency worktree:

```text
/private/tmp/context-efficiency-wip-20260715
```

Treat that worktree as the fresher source for current Phase 3 state.

Do not overwrite or discard unrelated dirty work in the current checkout.

Use subsessions during this implementation for bounded investigation tasks such as:

* mapping runtime identities
* inspecting rollout event shapes
* reviewing the WorkProvenance migration
* reviewing reconciliation logic
* developing the lifecycle test matrix

Keep the parent session focused on architecture and integration.

Require each child session to return:

```text
outcome
summary
files inspected
files changed
tests run
findings
unresolved risks
recommended next action
confidence
```

Do not paste full child transcripts into the parent context.

Before changing schema or code, return the Phase A architecture report.

After that report, proceed with the smallest complete implementation slice:

```text
read-only subsession lifecycle persistence
```

Do not jump directly to UI, analytics, or automated orchestration.
