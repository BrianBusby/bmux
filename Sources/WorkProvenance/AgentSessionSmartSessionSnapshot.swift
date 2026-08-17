import Foundation
import ProvenanceEngineContracts

/// Bridge snapshot for the React Smart Session consumer of PE SessionWorkModel.
struct AgentSessionSmartSessionSnapshot: Equatable, Sendable {
    let schemaVersion: Int
    let revision: Revision
    let identity: Identity
    let workModel: WorkModel
    let factual: Factual
    let semanticMessages: [SemanticMessage]

    init(
        workModel: ProvenanceSessionWorkModel,
        semanticMessages semanticMessageRecords: [ProvenanceSemanticMessageRecord]
    ) {
        let factualProjection = workModel.basis.factualSessionProjection
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
            workModelRevision: workModel.revision,
            semanticMessageCount: messages.count,
            latestSemanticMessageCreatedAt: messages.map(\.createdAt).max()
        )
        self.identity = Identity(factualProjection: factualProjection)
        self.workModel = WorkModel(model: workModel)
        self.factual = Factual(factualProjection: factualProjection)
        self.semanticMessages = messages
    }

    var bridgePayload: [String: Any] {
        [
            "schemaVersion": schemaVersion,
            "revision": revision.bridgePayload,
            "identity": identity.bridgePayload,
            "workModel": workModel.bridgePayload,
            "factual": factual.bridgePayload,
            "semanticMessages": semanticMessages.map(\.bridgePayload)
        ]
    }
}

extension AgentSessionSmartSessionSnapshot {
    struct WorkModel: Equatable, Sendable {
        let schemaVersion: Int
        let revision: WorkModelRevision
        let thread: WorkModelThread?
        let currentTurn: WorkModelCurrentTurn?
        let sessionPhase: SemanticField

        init(model: ProvenanceSessionWorkModel) {
            self.schemaVersion = model.schemaVersion
            self.revision = WorkModelRevision(revision: model.revision)
            self.thread = model.thread.map(WorkModelThread.init(thread:))
            self.currentTurn = model.currentTurn.map(WorkModelCurrentTurn.init(currentTurn:))
            self.sessionPhase = SemanticField(field: model.sessionPhase)
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "schemaVersion": schemaVersion,
                "revision": revision.bridgePayload,
                "thread": thread?.bridgePayload,
                "currentTurn": currentTurn?.bridgePayload,
                "sessionPhase": sessionPhase.bridgePayload
            ])
        }
    }

    struct WorkModelRevision: Equatable, Sendable {
        let schemaVersion: Int
        let factualRevision: Int?
        let semanticInferenceIDs: [String]
        let latestSemanticInferenceCreatedAt: Date?
        let modelRevisionKey: String

        init(revision: ProvenanceSessionWorkModelRevision) {
            self.schemaVersion = revision.schemaVersion
            self.factualRevision = revision.factualRevision
            self.semanticInferenceIDs = revision.semanticInferenceIDs
            self.latestSemanticInferenceCreatedAt = revision.latestSemanticInferenceCreatedAt
            self.modelRevisionKey = revision.modelRevisionKey
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "schemaVersion": schemaVersion,
                "factualRevision": factualRevision,
                "semanticInferenceIds": semanticInferenceIDs,
                "latestSemanticInferenceCreatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(
                    latestSemanticInferenceCreatedAt
                ),
                "modelRevisionKey": modelRevisionKey
            ])
        }
    }

    struct WorkModelThread: Equatable, Sendable {
        let identity: ProviderThread
        let intent: SemanticField

        init(thread: ProvenanceSessionWorkModelThread) {
            self.identity = ProviderThread(identity: thread.identity)
            self.intent = SemanticField(field: thread.intent)
        }

        var bridgePayload: [String: Any] {
            [
                "identity": identity.bridgePayload,
                "intent": intent.bridgePayload
            ]
        }
    }

    struct WorkModelCurrentTurn: Equatable, Sendable {
        let turnID: String
        let threadID: String?
        let intent: SemanticField
        let currentActivity: SemanticField

        init(currentTurn: ProvenanceSessionWorkModelCurrentTurn) {
            self.turnID = currentTurn.turn.id
            self.threadID = currentTurn.turn.threadID
            self.intent = SemanticField(field: currentTurn.intent)
            self.currentActivity = SemanticField(field: currentTurn.currentActivity)
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "turnId": turnID,
                "threadId": threadID,
                "intent": intent.bridgePayload,
                "currentActivity": currentActivity.bridgePayload
            ])
        }
    }

    struct SemanticField: Equatable, Sendable {
        let kind: String
        let scope: String
        let scopeID: String?
        let state: String
        let reason: String?
        let record: SemanticRecord?
        let summary: String?
        let detail: String?

        init(field: ProvenanceSessionWorkModelSemanticField) {
            self.kind = field.kind
            self.scope = field.scope.rawValue
            self.scopeID = field.scopeID
            self.state = field.state.rawValue
            self.reason = field.reason
            self.record = field.record.map(SemanticRecord.init(record:))
            self.summary = Self.summary(kind: field.kind, record: field.record)
            self.detail = Self.detail(kind: field.kind, record: field.record)
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "kind": kind,
                "scope": scope,
                "scopeId": scopeID,
                "state": state,
                "reason": reason,
                "record": record?.bridgePayload,
                "summary": summary,
                "detail": detail
            ])
        }

    }

    struct SemanticRecord: Equatable, Sendable {
        let inferenceID: String
        let schemaVersion: Int
        let payload: ProvenanceSemanticPayloadValue
        let supportingEvidenceRefs: [SemanticEvidenceRef]
        let supportingFactualRevision: Int?
        let confidence: String
        let specificity: String
        let producerType: String
        let producerID: String
        let producerVersion: String
        let createdAt: Date
        let status: String
        let supersedes: [String]
        let supersededBy: String?

        init(record: ProvenanceSessionWorkModelSemanticRecord) {
            self.inferenceID = record.inferenceID
            self.schemaVersion = record.schemaVersion
            self.payload = record.payload
            self.supportingEvidenceRefs = record.supportingEvidenceRefs.map(SemanticEvidenceRef.init(ref:))
            self.supportingFactualRevision = record.supportingFactualRevision
            self.confidence = record.confidence.rawValue
            self.specificity = record.specificity.rawValue
            self.producerType = record.producerType.rawValue
            self.producerID = record.producerID
            self.producerVersion = record.producerVersion
            self.createdAt = record.createdAt
            self.status = record.status.rawValue
            self.supersedes = record.supersedes
            self.supersededBy = record.supersededBy
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "inferenceId": inferenceID,
                "schemaVersion": schemaVersion,
                "payload": AgentSessionSmartSessionBridgeDictionary.payloadValue(payload),
                "supportingEvidenceRefs": supportingEvidenceRefs.map(\.bridgePayload),
                "supportingFactualRevision": supportingFactualRevision,
                "confidence": confidence,
                "specificity": specificity,
                "producerType": producerType,
                "producerId": producerID,
                "producerVersion": producerVersion,
                "createdAt": AgentSessionSmartSessionBridgeDictionary.isoString(createdAt),
                "status": status,
                "supersedes": supersedes,
                "supersededBy": supersededBy
            ])
        }
    }

    struct SemanticEvidenceRef: Equatable, Sendable {
        let kind: String
        let id: String
        let ledgerSequence: Int?
        let factualRevision: Int?

        init(ref: ProvenanceSemanticEvidenceReference) {
            self.kind = ref.kind
            self.id = ref.id
            self.ledgerSequence = ref.ledgerSequence
            self.factualRevision = ref.factualRevision
        }

        var bridgePayload: [String: Any] {
            AgentSessionSmartSessionBridgeDictionary.compact([
                "kind": kind,
                "id": id,
                "ledgerSequence": ledgerSequence,
                "factualRevision": factualRevision
            ])
        }
    }

    struct Revision: Equatable, Sendable {
        let schemaVersion: Int
        let factualRevision: Int?
        let semanticInferenceIDs: [String]
        let latestSemanticInferenceCreatedAt: Date?
        let modelRevisionKey: String
        let semanticMessageCount: Int
        let latestSemanticMessageCreatedAt: Date?
        let key: String

        init(
            workModelRevision: ProvenanceSessionWorkModelRevision,
            semanticMessageCount: Int,
            latestSemanticMessageCreatedAt: Date?
        ) {
            self.schemaVersion = workModelRevision.schemaVersion
            self.factualRevision = workModelRevision.factualRevision
            self.semanticInferenceIDs = workModelRevision.semanticInferenceIDs
            self.latestSemanticInferenceCreatedAt = workModelRevision.latestSemanticInferenceCreatedAt
            self.modelRevisionKey = workModelRevision.modelRevisionKey
            self.semanticMessageCount = semanticMessageCount
            self.latestSemanticMessageCreatedAt = latestSemanticMessageCreatedAt
            self.key = [
                workModelRevision.modelRevisionKey,
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
            switch (latestSemanticInferenceCreatedAt, other.latestSemanticInferenceCreatedAt) {
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
            if semanticInferenceIDs != other.semanticInferenceIDs {
                return semanticInferenceIDs.count > other.semanticInferenceIDs.count
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
                "schemaVersion": schemaVersion,
                "factualRevision": factualRevision,
                "semanticInferenceIds": semanticInferenceIDs,
                "latestSemanticInferenceCreatedAt": AgentSessionSmartSessionBridgeDictionary.isoString(
                    latestSemanticInferenceCreatedAt
                ),
                "modelRevisionKey": modelRevisionKey,
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

    static func payloadValue(_ value: ProvenanceSemanticPayloadValue) -> Any {
        switch value {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        case let .string(value):
            return value
        case let .array(values):
            return values.map { Self.payloadValue($0) }
        case let .object(values):
            return values.mapValues { Self.payloadValue($0) }
        }
    }
}
