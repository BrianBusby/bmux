import Foundation

/// Factual diagnostic status for resolving a workspace to a coding-agent session projection.
public enum ProvenanceWorkspaceCodingAgentSessionReadinessStatus: String, Codable, Equatable, Sendable {
    case noSupportedCodingAgentDetected
    case agentDetectedAwaitingFirstPrompt
    case promptObservedAssociationPending
    case associationEstablishedProjectionPending
    case ingestionFailed
    case identityReconciliationFailed
    case projectionFailed
    case unsupportedOrUnassociatedSession
    case available
}

/// Bounded diagnostic state for the workspace-to-coding-agent-session pipeline.
public struct ProvenanceWorkspaceCodingAgentSessionReadiness: Codable, Equatable, Sendable {
    /// Current factual status.
    public let status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus

    /// Stable workspace identifier requested by the caller.
    public let workspaceID: String

    /// Agent kind being resolved.
    public let agentKind: String

    /// Canonical session id, when known.
    public let sessionID: String?

    /// Raw source session id, when known.
    public let rawSessionID: String?

    /// Canonical session id selected by identity reconciliation, when known.
    public let canonicalSessionID: String?

    /// Evidence source path, such as hook, transcript, sidecar, lifecycle, display, or replay.
    public let sourcePath: String?

    /// Current pipeline stage.
    public let stage: String

    /// Stable reason code for diagnostics.
    public let reasonCode: String?

    /// Whether retrying or waiting can reasonably converge this state.
    public let retryable: Bool

    /// First time relevant evidence was observed, when known.
    public let firstObservedAt: Date?

    /// Prompt-observation time, when known.
    public let promptObservedAt: Date?

    /// Last stage transition time, when known.
    public let lastTransitionAt: Date?

    /// Latest event id known to affect this state.
    public let latestEventID: String?

    /// Latest projection or evidence revision known to affect this state.
    public let latestEventSequence: Int?

    /// Creates a workspace coding-agent session readiness value.
    public init(
        status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus,
        workspaceID: String,
        agentKind: String,
        sessionID: String? = nil,
        rawSessionID: String? = nil,
        canonicalSessionID: String? = nil,
        sourcePath: String? = nil,
        stage: String,
        reasonCode: String? = nil,
        retryable: Bool,
        firstObservedAt: Date? = nil,
        promptObservedAt: Date? = nil,
        lastTransitionAt: Date? = nil,
        latestEventID: String? = nil,
        latestEventSequence: Int? = nil
    ) {
        self.status = status
        self.workspaceID = workspaceID
        self.agentKind = agentKind
        self.sessionID = sessionID
        self.rawSessionID = rawSessionID
        self.canonicalSessionID = canonicalSessionID
        self.sourcePath = sourcePath
        self.stage = stage
        self.reasonCode = reasonCode
        self.retryable = retryable
        self.firstObservedAt = firstObservedAt
        self.promptObservedAt = promptObservedAt
        self.lastTransitionAt = lastTransitionAt
        self.latestEventID = latestEventID
        self.latestEventSequence = latestEventSequence
    }
}
