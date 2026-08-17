import Foundation
import ProvenanceEngineContracts

/// Read outcome for one PE factual coding-agent session projection.
enum AgentSessionFactualProjectionReadResult: Equatable, Sendable {
    case missingSession
    case unavailable
    case notFound(sessionID: String, reason: String?)
    case failed(sessionID: String?)
    case available(ProvenanceFactualSessionProjectionSnapshot)
}
