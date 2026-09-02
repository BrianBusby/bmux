import Foundation
import ProvenanceEngineContracts

/// Read outcome for one PE factual coding-agent session projection.
enum AgentSessionFactualProjectionReadResult: Equatable, Sendable {
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
    case available(ProvenanceFactualSessionProjectionSnapshot)
}
