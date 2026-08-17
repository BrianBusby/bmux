import Foundation

/// Read outcome for the first React Smart Session bridge snapshot.
enum AgentSessionSmartSessionReadResult: Equatable, Sendable {
    case missingSession
    case unavailable
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
}
