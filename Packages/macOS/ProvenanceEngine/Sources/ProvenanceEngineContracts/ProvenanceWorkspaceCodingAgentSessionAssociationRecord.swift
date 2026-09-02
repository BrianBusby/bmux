import Foundation

/// PE-owned current-state association between one client workspace and one coding-agent session.
public struct ProvenanceWorkspaceCodingAgentSessionAssociationRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable projection identifier derived from workspace, agent kind, and canonical session id.
    public let id: String

    /// Stable client workspace identifier.
    public let workspaceID: String

    /// Canonical PE coding-agent session identifier.
    public let sessionID: String

    /// Agent kind, such as `codex`.
    public let agentKind: String

    /// Raw provider or hook session identifier when it differs from the canonical session id.
    public let rawSessionID: String?

    /// Canonical session identifier selected by identity reconciliation.
    public let canonicalSessionID: String

    /// Client surface identifier, when known.
    public let surfaceID: String?

    /// Linked repository identifier, when known.
    public let repositoryID: String?

    /// Linked worktree identifier, when known.
    public let worktreeID: String?

    /// Current or launch working directory, when known.
    public let currentDirectory: String?

    /// Evidence source path that last strengthened this association.
    public let sourcePath: String

    /// Diagnostic stage for the association pipeline.
    public let stage: String

    /// Stable reason code for the current diagnostic stage.
    public let reasonCode: String?

    /// Whether the current diagnostic state is expected to converge with more evidence.
    public let retryable: Bool

    /// First time this logical association was observed.
    public let firstObservedAt: Date

    /// First prompt-observation time known for this association, when available.
    public let promptObservedAt: Date?

    /// Last time evidence for this association was observed.
    public let lastObservedAt: Date

    /// Last stage transition time.
    public let lastTransitionAt: Date

    /// Durable event ID whose payload last updated this projection.
    public let latestEventID: String?

    /// Append-order ledger sequence whose payload last updated this projection.
    public let latestEventSequence: Int?

    /// Creates a workspace coding-agent session association record.
    public init(
        id: String,
        workspaceID: String,
        sessionID: String,
        agentKind: String,
        rawSessionID: String? = nil,
        canonicalSessionID: String? = nil,
        surfaceID: String? = nil,
        repositoryID: String? = nil,
        worktreeID: String? = nil,
        currentDirectory: String? = nil,
        sourcePath: String,
        stage: String,
        reasonCode: String? = nil,
        retryable: Bool = true,
        firstObservedAt: Date,
        promptObservedAt: Date? = nil,
        lastObservedAt: Date,
        lastTransitionAt: Date,
        latestEventID: String? = nil,
        latestEventSequence: Int? = nil
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.sessionID = sessionID
        self.agentKind = agentKind
        self.rawSessionID = rawSessionID
        self.canonicalSessionID = canonicalSessionID ?? sessionID
        self.surfaceID = surfaceID
        self.repositoryID = repositoryID
        self.worktreeID = worktreeID
        self.currentDirectory = currentDirectory
        self.sourcePath = sourcePath
        self.stage = stage
        self.reasonCode = reasonCode
        self.retryable = retryable
        self.firstObservedAt = firstObservedAt
        self.promptObservedAt = promptObservedAt
        self.lastObservedAt = lastObservedAt
        self.lastTransitionAt = lastTransitionAt
        self.latestEventID = latestEventID
        self.latestEventSequence = latestEventSequence
    }
}
