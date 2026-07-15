# Bmux Context Efficiency: Domain Model

Status: proposed canonical vocabulary for Milestone 1/2. Types are expressed as Swift-shaped records, but no implementation is created by this document.

## Model Rules

- Every persisted record has an explicit schema version.
- IDs are stable strings, not UI object pointers.
- UI identities such as workspace/window/surface IDs are references, not substitutes for logical agent thread IDs.
- Facts and inferences are stored separately.
- Raw evidence is referenced by artifact IDs and source offsets.
- Large content is stored outside frequently queried SQLite rows.
- Policy names, thresholds, parser behavior, and handoff schemas are versioned.

## Common Types

```swift
struct ContextSchemaVersion: Codable, Sendable {
    var major: Int
    var minor: Int
}

enum EvidenceSourceKind: String, Codable, Sendable {
    case observed
    case declared
    case imported
    case inferred
    case userAuthored
}

enum Confidence: String, Codable, Sendable {
    case low
    case medium
    case high
    case exact
}

struct SourceReference: Codable, Sendable, Hashable {
    var artifactID: String?
    var filePath: String?
    var byteOffset: Int64?
    var lineNumber: Int?
    var eventID: String?
    var parserVersion: String?
}
```

Existing alignment:

- `WorkProvenanceSource` and `WorkProvenanceConfidence` already model a similar source/confidence distinction.
- `WorkProvenanceEvent` already stores `schemaVersion` and a typed payload.

## Workspace

Represents a bmux workspace that can contain one or more panels, surfaces, terminal sessions, repositories, worktrees, and agent threads.

```swift
struct WorkspaceRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var bmuxWorkspaceID: String
    var stableWorkspaceID: String?
    var windowID: String?
    var displayName: String?
    var currentDirectory: String?
    var repositoryIDs: [String]
    var activeWorkItemIDs: [String]
    var createdAt: Date?
    var updatedAt: Date
}
```

Existing sources:

- `Workspace.id`, `Workspace.stableId`, `Workspace.currentDirectory`, `Workspace.groupId`.
- `SessionWorkspaceSnapshot` for restore-time workspace state.

## Repository

```swift
struct RepositoryRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var canonicalPath: String
    var gitDirectory: String?
    var commonDirectory: String?
    var remoteOrigin: String?
    var remoteSlug: String?
    var defaultBranch: String?
    var createdAt: Date?
    var updatedAt: Date
}
```

Existing sources:

- `ResolvedGitRepository` from `BmuxGit`.
- `WorkProvenanceRepositoryRecord`.

## Worktree

```swift
struct WorktreeRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var repositoryID: String
    var path: String
    var branch: String?
    var baseCommit: String?
    var headCommit: String?
    var creationSource: String?
    var status: WorktreeStatus
    var isDirty: Bool?
    var lastReconciledAt: Date?
    var updatedAt: Date
}

enum WorktreeStatus: String, Codable, Sendable {
    case active
    case archived
    case missing
    case unknown
}
```

Existing sources:

- `WorkProvenanceWorktreeRecord`.
- `WorkProvenanceGitSnapshot`.

## Agent Thread

A logical Codex conversation independent from a terminal tab or surface.

```swift
struct AgentThreadRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var agentKind: String
    var externalThreadID: String?
    var rolloutSessionID: String?
    var model: String?
    var reasoningLevel: String?
    var serviceTier: String?
    var startTime: Date?
    var endTime: Date?
    var workspaceID: String?
    var repositoryID: String?
    var worktreeID: String?
    var terminalSessionIDs: [String]
    var parentThreadID: String?
    var handoffSourceID: String?
    var status: AgentThreadStatus
    var lifecycleState: ThreadLifecycleState
    var cumulativeTokens: TokenTotals
    var currentEstimatedContextTokens: Int64?
    var compactionCount: Int
    var modelCallCount: Int
    var sourceReferences: [SourceReference]
    var updatedAt: Date
}

enum AgentThreadStatus: String, Codable, Sendable {
    case active
    case ended
    case interrupted
    case archived
    case unknown
}

enum ThreadLifecycleState: String, Codable, Sendable {
    case normal
    case highContext
    case handoffRecommended
    case handoffPrepared
    case handedOff
    case blocked
    case unknown
}
```

Existing sources:

- `AgentChatSessionRecord` for live session binding.
- Codex `threads` SQLite rows for model/cwd/branch/title/rollout metadata.
- Codex rollout filename/session ID.

Important distinction:

- One `AgentThreadRecord` can have zero, one, or many `TerminalSessionRecord`s over time. Do not assume one terminal session equals one logical thread.

## Terminal Session

```swift
struct TerminalSessionRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var bmuxSurfaceID: String
    var bmuxWorkspaceID: String?
    var bmuxWindowID: String?
    var ptyIdentifier: String?
    var rootProcessID: Int?
    var processTreeSnapshotIDs: [String]
    var associatedThreadID: String?
    var startedAt: Date?
    var endedAt: Date?
    var updatedAt: Date
}
```

Existing sources:

- `BMUX_SURFACE_ID` and related spawn env.
- `AgentChatSessionRecord.surfaceID`.
- Terminal process observation and control socket reports.

## Model Call

```swift
struct ModelCallRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var threadID: String
    var externalCallID: String?
    var timestamp: Date
    var inputTokens: Int64?
    var cachedInputTokens: Int64?
    var nonCachedInputTokens: Int64?
    var outputTokens: Int64?
    var reasoningOutputTokens: Int64?
    var totalTokens: Int64?
    var estimatedContextTokens: Int64?
    var contextWindowCapacity: Int64?
    var classification: ModelCallClassification
    var nearbyCommandIDs: [String]
    var telemetrySource: String
    var telemetryConfidence: Confidence
    var sourceReferences: [SourceReference]
}

enum ModelCallClassification: String, Codable, Sendable {
    case normal
    case compaction
    case toolHeavy
    case lowInformationHighContext
    case unknown
}
```

Parser rule:

- If Codex only exposes cumulative totals, store exact cumulative facts and derived deltas separately. Do not invent cached/non-cached splits.

## Token Totals

```swift
struct TokenTotals: Codable, Sendable, Equatable {
    var inputTokens: Int64?
    var cachedInputTokens: Int64?
    var nonCachedInputTokens: Int64?
    var outputTokens: Int64?
    var reasoningOutputTokens: Int64?
    var totalTokens: Int64?
}
```

## Command Execution

```swift
struct CommandExecutionRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var threadID: String?
    var terminalSessionID: String?
    var toolCallID: String?
    var normalizedExecutable: String?
    var normalizedArguments: [String]
    var rawCommandText: String
    var workingDirectory: String?
    var startedAt: Date?
    var completedAt: Date?
    var exitStatus: Int?
    var stdoutArtifactID: String?
    var stderrArtifactID: String?
    var rawByteCount: Int64?
    var estimatedRawTokens: Int64?
    var reducedByteCount: Int64?
    var estimatedReducedTokens: Int64?
    var category: CommandCategory
    var mentionedFiles: [String]
    var affectedFiles: [String]
    var attribution: Attribution
}

enum CommandCategory: String, Codable, Sendable {
    case sourceSearch
    case fileRead
    case gitStatus
    case gitDiff
    case gitLog
    case tests
    case build
    case typecheck
    case lint
    case packageInstall
    case codeGeneration
    case serverLogs
    case directoryListing
    case processMonitoring
    case arbitrary
    case unknown
}
```

Existing sources:

- Codex `function_call` and `function_call_output` rollout records.
- `OSC133CommandParser` for PTY streams.
- `agent-token-proxy` raw-output refs and command metadata.

## Evidence Artifact

```swift
struct EvidenceArtifactRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var type: EvidenceArtifactType
    var storageLocation: String
    var contentHash: String?
    var byteCount: Int64
    var estimatedTokens: Int64?
    var producerEventID: String?
    var createdAt: Date
    var retentionPolicyID: String
    var redactionState: RedactionState
}

enum EvidenceArtifactType: String, Codable, Sendable {
    case rolloutJSONL
    case terminalOutput
    case toolOutput
    case stdout
    case stderr
    case diff
    case testReport
    case screenshot
    case summary
    case analyzerOutput
    case unknown
}

enum RedactionState: String, Codable, Sendable {
    case raw
    case redacted
    case metadataOnly
}
```

Existing sources:

- `ChatRawTerminalOutputRecord`.
- Codex rollout file path and byte offsets.
- Future content-addressed artifact store.

## Work Item

```swift
struct WorkItemRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var objective: String
    var status: WorkItemStatus
    var repositoryID: String?
    var relatedIssueURL: String?
    var parentWorkItemID: String?
    var acceptanceCriteria: [String]
    var activeThreadIDs: [String]
    var provenanceLinkIDs: [String]
    var createdAt: Date
    var updatedAt: Date
}

enum WorkItemStatus: String, Codable, Sendable {
    case proposed
    case active
    case completed
    case blocked
    case superseded
    case unknown
}
```

Existing sources:

- `WorkProvenanceWorkItemRecord` is a smaller current-state projection.

## Work Contribution

```swift
struct WorkContributionRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var workItemID: String
    var threadID: String
    var worktreeID: String?
    var filesChanged: [String]
    var commits: [String]
    var decisionIDs: [String]
    var validationRunIDs: [String]
    var startedAt: Date
    var endedAt: Date?
    var confidence: Confidence
    var evidenceReferences: [SourceReference]
}
```

Existing sources:

- `WorkProvenanceContributionRecord`.
- Git status/commit checks.

## Decision, Discovery, Failed Approach, Invariant, Open Question

```swift
struct DecisionRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var statement: String
    var rationale: String?
    var status: DecisionStatus
    var authorType: AuthorType
    var supportingEvidence: [SourceReference]
    var supersededDecisionID: String?
    var affectedWorkItemIDs: [String]
    var affectedFiles: [String]
    var createdAt: Date
}

enum DecisionStatus: String, Codable, Sendable {
    case proposed
    case accepted
    case superseded
    case rejected
    case unknown
}

enum AuthorType: String, Codable, Sendable {
    case user
    case agent
    case inferred
}

struct DiscoveryRecord: Codable, Sendable, Identifiable {
    var id: String
    var fact: String
    var sourceReferences: [SourceReference]
    var confidence: Confidence
    var createdAt: Date
}

struct FailedApproachRecord: Codable, Sendable, Identifiable {
    var id: String
    var attemptedApproach: String
    var failureReason: String
    var shouldRetry: Bool
    var supportingEvidence: [SourceReference]
    var createdAt: Date
}

struct InvariantRecord: Codable, Sendable, Identifiable {
    var id: String
    var statement: String
    var sourceReferences: [SourceReference]
    var createdAt: Date
}

struct OpenQuestionRecord: Codable, Sendable, Identifiable {
    var id: String
    var question: String
    var hypotheses: [String]
    var owner: String?
    var isBlocking: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

Rule:

- User-authored decisions outrank inferred records. Summaries can propose inferred decisions but cannot silently replace explicit user decisions.

## Handoff

```swift
struct HandoffRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var sourceThreadID: String
    var destinationThreadID: String?
    var trigger: String
    var policyVersion: String
    var summarySchemaVersion: String
    var includedStructuredDataArtifactID: String?
    var artifactReferences: [String]
    var estimatedTokenSize: Int64?
    var actualTokenSize: Int64?
    var subsequentRediscoveryMetrics: RediscoveryMetrics?
    var outcome: HandoffOutcome?
    var createdAt: Date
}

struct RediscoveryMetrics: Codable, Sendable {
    var filesReread: Int
    var commandsRepeated: Int
    var questionsRepeated: Int
    var decisionsRediscovered: Int
    var tokensBeforeUsefulProgress: Int64?
}

enum HandoffOutcome: String, Codable, Sendable {
    case accepted
    case ignored
    case successful
    case missingContext
    case failed
    case unknown
}
```

## Lifecycle Intervention

```swift
struct LifecycleInterventionRecord: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var threadID: String
    var interventionType: LifecycleInterventionType
    var policyVersion: String
    var triggerMeasurements: [String: String]
    var explanation: String
    var recommendation: String?
    var state: InterventionState
    var outcome: String?
    var createdAt: Date
    var resolvedAt: Date?
}

enum LifecycleInterventionType: String, Codable, Sendable {
    case shadowMarker
    case warning
    case handoffRecommendation
    case assistedHandoff
    case automaticHandoff
}

enum InterventionState: String, Codable, Sendable {
    case shadowOnly
    case shown
    case accepted
    case ignored
    case deferred
    case expired
}
```

## Attribution

```swift
struct Attribution: Codable, Sendable {
    var source: AttributionSource
    var confidence: Confidence
    var explanation: String?
    var sourceReferences: [SourceReference]
}

enum AttributionSource: String, Codable, Sendable {
    case directToolCall
    case temporalWindow
    case processTree
    case terminalMarkers
    case inferred
    case unknown
}
```

Rule:

- Temporal attribution can say "candidate input contributor"; it must not claim exact token causality unless exact evidence exists.

## Initial Event Schema

Milestone 2 should normalize imported Codex rollout/state data into small events before storage:

```swift
struct ContextEfficiencyEvent: Codable, Sendable, Identifiable {
    var id: String
    var schemaVersion: Int
    var eventType: ContextEfficiencyEventType
    var timestamp: Date?
    var threadID: String?
    var modelCallID: String?
    var commandID: String?
    var artifactID: String?
    var source: EvidenceSourceKind
    var confidence: Confidence
    var sourceReference: SourceReference
    var payload: ContextEfficiencyEventPayload
}

enum ContextEfficiencyEventType: String, Codable, Sendable {
    case codexThreadObserved
    case rolloutLineImported
    case tokenTelemetryObserved
    case modelCallObserved
    case compactionObserved
    case toolCallObserved
    case toolOutputObserved
    case commandObserved
    case parserErrorObserved
}
```

`ContextEfficiencyEventPayload` should be an explicit enum rather than an untyped dictionary in Swift code. Unknown fields can be preserved as bounded JSON metadata when needed.

## Relationship Summary

```text
WorkspaceRecord 1 -- many TerminalSessionRecord
WorkspaceRecord many -- many RepositoryRecord
RepositoryRecord 1 -- many WorktreeRecord
WorktreeRecord 1 -- many AgentThreadRecord
AgentThreadRecord 1 -- many ModelCallRecord
AgentThreadRecord 1 -- many CommandExecutionRecord
CommandExecutionRecord many -- many EvidenceArtifactRecord
WorkItemRecord 1 -- many WorkContributionRecord
WorkContributionRecord many -- one AgentThreadRecord
HandoffRecord links source AgentThreadRecord to destination AgentThreadRecord
LifecycleInterventionRecord belongs to one AgentThreadRecord
```

## Milestone 2 Minimal Tables

Minimum tables for read-only telemetry:

- `schema_migrations`
- `import_sources`
- `import_cursors`
- `parser_errors`
- `agent_threads`
- `model_calls`
- `token_telemetry_events`
- `rollout_events`
- `tool_calls`
- `tool_outputs`
- `evidence_artifacts`

Tables deferred until later:

- `command_executions`
- `work_items`
- `work_contributions`
- `decisions`
- `discoveries`
- `handoffs`
- `lifecycle_interventions`
- `policy_evaluations`

## Open Model Questions

- Should `AgentThreadRecord.id` be bmux-generated or derived from Codex thread/session ID plus source?
- Should the context-efficiency store share the existing WorkProvenance database or link to it?
- How much unknown JSON should be preserved per imported rollout event?
- Which token telemetry fields are exact in current Codex local files?
- Should raw rollout JSONL itself be represented as an `EvidenceArtifactRecord`, or should source file path plus offset be enough?
