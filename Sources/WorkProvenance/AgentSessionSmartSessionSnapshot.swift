import Foundation
import ProvenanceEngineContracts

/// First-pass bridge snapshot for React Smart Session.
///
/// This is consumer scaffolding for Slice 1. It transports PE factual projection
/// data and existing semantic presentation records without claiming to be the
/// PE-owned SessionWorkModel contract.
struct AgentSessionSmartSessionSnapshot: Equatable, Sendable {
    let schemaVersion: Int
    let revision: Revision
    let identity: Identity
    let factual: Factual
    let semanticMessages: [SemanticMessage]

    init(
        factualProjection: ProvenanceFactualSessionProjectionSnapshot,
        semanticMessages semanticMessageRecords: [ProvenanceSemanticMessageRecord]
    ) {
        let messages = semanticMessageRecords
            .sorted {
                if $0.scope.rawValue != $1.scope.rawValue {
                    return $0.scope.rawValue < $1.scope.rawValue
                }
                if $0.scopeID != $1.scopeID {
                    return $0.scopeID < $1.scopeID
                }
                if $0.semanticInferenceKind != $1.semanticInferenceKind {
                    return $0.semanticInferenceKind < $1.semanticInferenceKind
                }
                return $0.createdAt > $1.createdAt
            }
            .map(SemanticMessage.init(record:))
        self.schemaVersion = 1
        self.revision = Revision(
            factualRevision: factualProjection.revision,
            semanticMessageCount: messages.count,
            latestSemanticMessageCreatedAt: messages.map(\.createdAt).max()
        )
        self.identity = Identity(factualProjection: factualProjection)
        self.factual = Factual(factualProjection: factualProjection)
        self.semanticMessages = messages
    }

    var bridgePayload: [String: Any] {
        [
            "schemaVersion": schemaVersion,
            "revision": revision.bridgePayload,
            "identity": identity.bridgePayload,
            "factual": factual.bridgePayload,
            "semanticMessages": semanticMessages.map(\.bridgePayload)
        ]
    }

    struct Revision: Equatable, Sendable {
        let factualRevision: Int?
        let semanticMessageCount: Int
        let latestSemanticMessageCreatedAt: Date?
        let key: String

        init(
            factualRevision: Int?,
            semanticMessageCount: Int,
            latestSemanticMessageCreatedAt: Date?
        ) {
            self.factualRevision = factualRevision
            self.semanticMessageCount = semanticMessageCount
            self.latestSemanticMessageCreatedAt = latestSemanticMessageCreatedAt
            self.key = [
                "factual:\(factualRevision.map(String.init) ?? "unknown")",
                "semanticCount:\(semanticMessageCount)",
                "semanticLatest:\(AgentSessionSmartSessionBridgeDictionary.isoString(latestSemanticMessageCreatedAt) ?? "none")"
            ].joined(separator: "|")
        }

        func isNewerThan(_ other: Revision) -> Bool {
            switch (factualRevision, other.factualRevision) {
            case let (left?, right?) where left != right:
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                break
            }
            switch (latestSemanticMessageCreatedAt, other.latestSemanticMessageCreatedAt) {
            case let (left?, right?):
                if left != right {
                    return left > right
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return semanticMessageCount > other.semanticMessageCount
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "factualRevision": factualRevision,
                "semanticMessageCount": semanticMessageCount,
                "latestSemanticMessageCreatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(
                    latestSemanticMessageCreatedAt
                ),
                "key": key
            ])
        }
    }

    struct Identity: Equatable, Sendable {
        let sessionID: String
        let agentKind: String
        let workspaceID: String?
        let surfaceID: String?
        let worktreeID: String?
        let cwd: String?
        let status: String
        let startedAt: Date?
        let updatedAt: Date
        let providerThreads: [ProviderThread]

        init(factualProjection: ProvenanceFactualSessionProjectionSnapshot) {
            let session = factualProjection.session
            self.sessionID = session.id
            self.agentKind = session.agentKind
            self.workspaceID = session.workspaceID
            self.surfaceID = session.surfaceID
            self.worktreeID = session.worktreeID
            self.cwd = session.cwd
            self.status = session.status
            self.startedAt = session.startedAt
            self.updatedAt = session.updatedAt
            self.providerThreads = factualProjection.providerThreadIdentities.map(ProviderThread.init(identity:))
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "sessionId": sessionID,
                "agentKind": agentKind,
                "workspaceId": workspaceID,
                "surfaceId": surfaceID,
                "worktreeId": worktreeID,
                "cwd": cwd,
                "status": status,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.isoString(startedAt),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(updatedAt),
                "providerThreads": providerThreads.map(\.bridgePayload)
            ])
        }
    }

    struct ProviderThread: Equatable, Sendable {
        let threadID: String
        let provider: String
        let providerThreadID: String
        let worktreeID: String?
        let source: String
        let confidence: String
        let firstObservedAt: Date
        let updatedAt: Date

        init(identity: ProvenanceFactualSessionProjectionProviderThreadIdentity) {
            self.threadID = identity.threadID
            self.provider = identity.provider
            self.providerThreadID = identity.providerThreadID
            self.worktreeID = identity.worktreeID
            self.source = identity.source.rawValue
            self.confidence = identity.confidence.rawValue
            self.firstObservedAt = identity.firstObservedAt
            self.updatedAt = identity.updatedAt
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "threadId": threadID,
                "provider": provider,
                "providerThreadId": providerThreadID,
                "worktreeId": worktreeID,
                "source": source,
                "confidence": confidence,
                "firstObservedAt": AgentSessionSmartSessionBridgeDictionary.isoString(firstObservedAt),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(updatedAt)
            ])
        }
    }

    struct Factual: Equatable, Sendable {
        let latestTurn: Turn?
        let priorTurns: [TurnReference]
        let turnCount: Int

        init(factualProjection: ProvenanceFactualSessionProjectionSnapshot) {
            self.latestTurn = factualProjection.latestTurn.map(Turn.init(turnSnapshot:))
            self.priorTurns = factualProjection.priorTurns.map(TurnReference.init(reference:))
            self.turnCount = factualProjection.turns.count
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "latestTurn": latestTurn?.bridgePayload,
                "priorTurns": priorTurns.map(\.bridgePayload),
                "turnCount": turnCount
            ])
        }
    }

    struct Turn: Equatable, Sendable {
        let turnID: String
        let threadID: String?
        let provider: String
        let providerTurnID: String
        let status: String
        let model: String?
        let startedAt: Date?
        let completedAt: Date?
        let updatedAt: Date
        let prompt: Prompt?
        let plan: Plan?
        let completedCommands: [Command]
        let visibleReasoningSummaries: [ReasoningSummary]
        let fileChangeAttributions: [FileChangeAttribution]

        init(turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) {
            let turn = turnSnapshot.turn
            self.turnID = turn.id
            self.threadID = turn.threadID
            self.provider = turn.provider
            self.providerTurnID = turn.providerTurnID
            self.status = turn.status
            self.model = turn.model
            self.startedAt = turn.startedAt
            self.completedAt = turn.completedAt
            self.updatedAt = turn.updatedAt
            self.prompt = turnSnapshot.submittedPrompt.map(Prompt.init(record:))
            self.plan = turnSnapshot.currentPlan.map(Plan.init(record:))
            self.completedCommands = turnSnapshot.completedCommands.map(Command.init(record:))
            self.visibleReasoningSummaries = turnSnapshot.visibleReasoningSummaries.map(ReasoningSummary.init(record:))
            self.fileChangeAttributions = turnSnapshot.fileChangeAttributions.map(FileChangeAttribution.init(record:))
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "turnId": turnID,
                "threadId": threadID,
                "provider": provider,
                "providerTurnId": providerTurnID,
                "status": status,
                "model": model,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.isoString(startedAt),
                "completedAt": AgentSessionSmartSessionBridgeDictionary.isoString(completedAt),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(updatedAt),
                "prompt": prompt?.bridgePayload,
                "plan": plan?.bridgePayload,
                "completedCommands": completedCommands.map(\.bridgePayload),
                "visibleReasoningSummaries": visibleReasoningSummaries.map(\.bridgePayload),
                "fileChangeAttributions": fileChangeAttributions.map(\.bridgePayload)
            ])
        }
    }

    struct TurnReference: Equatable, Sendable {
        let turnID: String
        let threadID: String?
        let provider: String
        let providerTurnID: String
        let status: String
        let startedAt: Date?
        let completedAt: Date?
        let updatedAt: Date

        init(reference: ProvenanceFactualSessionProjectionTurnReference) {
            self.turnID = reference.turnID
            self.threadID = reference.threadID
            self.provider = reference.provider
            self.providerTurnID = reference.providerTurnID
            self.status = reference.status
            self.startedAt = reference.startedAt
            self.completedAt = reference.completedAt
            self.updatedAt = reference.updatedAt
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "turnId": turnID,
                "threadId": threadID,
                "provider": provider,
                "providerTurnId": providerTurnID,
                "status": status,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.isoString(startedAt),
                "completedAt": AgentSessionSmartSessionBridgeDictionary.isoString(completedAt),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(updatedAt)
            ])
        }
    }

    struct Prompt: Equatable, Sendable {
        let promptID: String
        let text: String
        let submittedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentPromptRecord) {
            self.promptID = record.id
            self.text = record.text
            self.submittedAt = record.submittedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            [
                "promptId": promptID,
                "text": text,
                "submittedAt": AgentSessionSmartSessionBridgeDictionary.isoString(submittedAt),
                "source": source,
                "confidence": confidence
            ]
        }
    }

    struct Plan: Equatable, Sendable {
        let planID: String
        let explanation: String?
        let observedAt: Date
        let source: String
        let confidence: String
        let steps: [PlanStep]

        init(record: ProvenanceCodingAgentPlanUpdateRecord) {
            self.planID = record.id
            self.explanation = record.explanation
            self.observedAt = record.observedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
            self.steps = record.steps.sorted { $0.order < $1.order }.map(PlanStep.init(record:))
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "planId": planID,
                "explanation": explanation,
                "observedAt": AgentSessionSmartSessionBridgeDictionary.isoString(observedAt),
                "source": source,
                "confidence": confidence,
                "steps": steps.map(\.bridgePayload)
            ])
        }
    }

    struct PlanStep: Equatable, Sendable {
        let stepID: String
        let order: Int
        let text: String
        let status: String

        init(record: ProvenanceCodingAgentPlanStepRecord) {
            self.stepID = record.id
            self.order = record.order
            self.text = record.text
            self.status = record.status
        }

        var bridgePayload: [String: Any] {
            [
                "stepId": stepID,
                "order": order,
                "text": text,
                "status": status
            ]
        }
    }

    struct Command: Equatable, Sendable {
        let commandID: String
        let command: String
        let cwd: String?
        let status: String
        let exitCode: Int?
        let outputSummary: String?
        let startedAt: Date?
        let completedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentCommandRecord) {
            self.commandID = record.id
            self.command = record.command
            self.cwd = record.cwd
            self.status = record.status
            self.exitCode = record.exitCode
            self.outputSummary = record.outputSummary
            self.startedAt = record.startedAt
            self.completedAt = record.completedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "commandId": commandID,
                "command": command,
                "cwd": cwd,
                "status": status,
                "exitCode": exitCode,
                "outputSummary": outputSummary,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.isoString(startedAt),
                "completedAt": AgentSessionSmartSessionBridgeDictionary.isoString(completedAt),
                "source": source,
                "confidence": confidence
            ])
        }
    }

    struct ReasoningSummary: Equatable, Sendable {
        let summaryID: String
        let text: String
        let completedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentReasoningSummaryRecord) {
            self.summaryID = record.id
            self.text = record.text
            self.completedAt = record.completedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            [
                "summaryId": summaryID,
                "text": text,
                "completedAt": AgentSessionSmartSessionBridgeDictionary.isoString(completedAt),
                "source": source,
                "confidence": confidence
            ]
        }
    }

    struct FileChangeAttribution: Equatable, Sendable {
        let attributionID: String
        let paths: [String]
        let summary: String?
        let observedAt: Date
        let source: String
        let confidence: String

        init(record: ProvenanceCodingAgentFileChangeAttributionRecord) {
            self.attributionID = record.id
            self.paths = record.paths
            self.summary = record.summary
            self.observedAt = record.observedAt
            self.source = record.source.rawValue
            self.confidence = record.confidence.rawValue
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "attributionId": attributionID,
                "paths": paths,
                "summary": summary,
                "observedAt": AgentSessionSmartSessionBridgeDictionary.isoString(observedAt),
                "source": source,
                "confidence": confidence
            ])
        }
    }

    struct SemanticMessage: Equatable, Sendable {
        let messageID: String
        let semanticInferenceID: String
        let semanticInferenceKind: String
        let scope: String
        let scopeID: String
        let concisePhrase: String
        let expandedMeaning: String
        let supportingFactualRevision: Int?
        let confidence: String
        let specificity: String
        let presentationProducerID: String
        let presentationProducerVersion: String
        let presentationPolicyID: String
        let presentationPolicyVersion: String
        let localeIdentifier: String?
        let createdAt: Date
        let status: String

        init(record: ProvenanceSemanticMessageRecord) {
            self.messageID = record.id
            self.semanticInferenceID = record.semanticInferenceID
            self.semanticInferenceKind = record.semanticInferenceKind
            self.scope = record.scope.rawValue
            self.scopeID = record.scopeID
            self.concisePhrase = record.concisePhrase
            self.expandedMeaning = record.expandedMeaning
            self.supportingFactualRevision = record.supportingFactualRevision
            self.confidence = record.confidence.rawValue
            self.specificity = record.specificity.rawValue
            self.presentationProducerID = record.presentationProducerID
            self.presentationProducerVersion = record.presentationProducerVersion
            self.presentationPolicyID = record.presentationPolicyID
            self.presentationPolicyVersion = record.presentationPolicyVersion
            self.localeIdentifier = record.localeIdentifier
            self.createdAt = record.createdAt
            self.status = record.status.rawValue
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "messageId": messageID,
                "semanticInferenceId": semanticInferenceID,
                "semanticInferenceKind": semanticInferenceKind,
                "scope": scope,
                "scopeId": scopeID,
                "concisePhrase": concisePhrase,
                "expandedMeaning": expandedMeaning,
                "supportingFactualRevision": supportingFactualRevision,
                "confidence": confidence,
                "specificity": specificity,
                "presentationProducerId": presentationProducerID,
                "presentationProducerVersion": presentationProducerVersion,
                "presentationPolicyId": presentationPolicyID,
                "presentationPolicyVersion": presentationPolicyVersion,
                "localeIdentifier": localeIdentifier,
                "createdAt": AgentSessionSmartSessionBridgeDictionary.isoString(createdAt),
                "status": status
            ])
        }
    }
}

enum AgentSessionSmartSessionBridgeDictionary {
    static func compact(_ values: [String: Any?]) -> [String: Any] {
        values.reduce(into: [String: Any]()) { partialResult, pair in
            if let value = pair.value {
                partialResult[pair.key] = value
            }
        }
    }

    static func isoString(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func isoString(_ date: Date) -> String {
        isoString(Optional(date)) ?? ""
    }
}
