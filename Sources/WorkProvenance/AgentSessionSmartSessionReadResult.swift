import Foundation
import ProvenanceEngineContracts

/// Read outcome for the first React Smart Session bridge snapshot.
enum AgentSessionSmartSessionReadResult: Equatable, Sendable {
    case missingSession
    case unavailable
    case noSupportedCodingAgentDetected(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case agentDetectedAwaitingFirstPrompt(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case promptObservedAssociationPending(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case associationEstablishedProjectionPending(sessionID: String, ProvenanceWorkspaceCodingAgentSessionReadiness)
    case ingestionFailed(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case identityReconciliationFailed(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case projectionFailed(sessionID: String?, ProvenanceWorkspaceCodingAgentSessionReadiness?)
    case unsupportedOrUnassociatedSession(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case notFound(sessionID: String, reason: String?)
    case failed(sessionID: String?)
    case available(AgentSessionSmartSessionSnapshot)

    var bridgePayload: [String: Any] {
        switch self {
        case .missingSession:
            return [
                "schemaVersion": 1,
                "status": "missingSession"
            ]
        case .unavailable:
            return [
                "schemaVersion": 1,
                "status": "unavailable"
            ]
        case let .noSupportedCodingAgentDetected(readiness):
            return readinessPayload(readiness)
        case let .agentDetectedAwaitingFirstPrompt(readiness):
            return readinessPayload(readiness)
        case let .promptObservedAssociationPending(readiness):
            return readinessPayload(readiness)
        case let .associationEstablishedProjectionPending(sessionID, readiness):
            return readinessPayload(readiness, sessionID: sessionID)
        case let .ingestionFailed(readiness):
            return readinessPayload(readiness)
        case let .identityReconciliationFailed(readiness):
            return readinessPayload(readiness)
        case let .projectionFailed(sessionID, readiness):
            if let readiness {
                return readinessPayload(readiness, sessionID: sessionID)
            }
            return AgentSessionSmartSessionBridgeDictionary.compact([
                "schemaVersion": 1,
                "status": "projectionFailed",
                "sessionId": sessionID
            ])
        case let .unsupportedOrUnassociatedSession(readiness):
            return readinessPayload(readiness)
        case let .notFound(sessionID, reason):
            return AgentSessionSmartSessionBridgeDictionary.compact([
                "schemaVersion": 1,
                "status": "notFound",
                "sessionId": sessionID,
                "reason": reason
            ])
        case let .failed(sessionID):
            return AgentSessionSmartSessionBridgeDictionary.compact([
                "schemaVersion": 1,
                "status": "failed",
                "sessionId": sessionID
            ])
        case let .available(snapshot):
            return [
                "schemaVersion": 1,
                "status": "available",
                "snapshot": snapshot.bridgePayload
            ]
        }
    }

    private func readinessPayload(
        _ readiness: ProvenanceWorkspaceCodingAgentSessionReadiness,
        sessionID: String? = nil
    ) -> [String: Any] {
        AgentSessionSmartSessionBridgeDictionary.compact([
            "schemaVersion": 1,
            "status": readiness.status.rawValue,
            "sessionId": sessionID ?? readiness.sessionID,
            "reason": readiness.reasonCode,
            "diagnostics": AgentSessionSmartSessionBridgeDictionary.compact([
                "workspaceId": readiness.workspaceID,
                "agentKind": readiness.agentKind,
                "sessionId": readiness.sessionID,
                "rawSessionId": readiness.rawSessionID,
                "canonicalSessionId": readiness.canonicalSessionID,
                "sourcePath": readiness.sourcePath,
                "stage": readiness.stage,
                "reasonCode": readiness.reasonCode,
                "retryable": readiness.retryable,
                "firstObservedAt": readiness.firstObservedAt?.timeIntervalSince1970,
                "promptObservedAt": readiness.promptObservedAt?.timeIntervalSince1970,
                "lastTransitionAt": readiness.lastTransitionAt?.timeIntervalSince1970,
                "latestEventId": readiness.latestEventID,
                "latestEventSequence": readiness.latestEventSequence
            ])
        ])
    }
}
