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
}

extension AgentSessionSmartSessionSnapshot {
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
                "factualRevision": AgentSessionSmartSessionBridgeDictionary.optional(factualRevision),
                "semanticMessageCount": semanticMessageCount,
                "latestSemanticMessageCreatedAt": AgentSessionSmartSessionBridgeDictionary.optional(
                    AgentSessionSmartSessionBridgeDictionary.isoString(latestSemanticMessageCreatedAt)
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
                "workspaceId": AgentSessionSmartSessionBridgeDictionary.optional(workspaceID),
                "surfaceId": AgentSessionSmartSessionBridgeDictionary.optional(surfaceID),
                "worktreeId": AgentSessionSmartSessionBridgeDictionary.optional(worktreeID),
                "cwd": AgentSessionSmartSessionBridgeDictionary.optional(cwd),
                "status": status,
                "startedAt": AgentSessionSmartSessionBridgeDictionary.optional(
                    AgentSessionSmartSessionBridgeDictionary.isoString(startedAt)
                ),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(updatedAt),
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
                "worktreeId": AgentSessionSmartSessionBridgeDictionary.optional(worktreeID),
                "source": source,
                "confidence": confidence,
                "firstObservedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(firstObservedAt),
                "updatedAt": AgentSessionSmartSessionBridgeDictionary.requiredISOString(updatedAt)
            ])
        }
    }
}

enum AgentSessionSmartSessionBridgeDictionary {
    static func optional<T>(_ value: T?) -> Any? {
        guard let value else { return nil }
        return value
    }

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

    static func requiredISOString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

}
