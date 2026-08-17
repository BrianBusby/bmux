import Foundation

/// Request to record one normalized session lifecycle transition.
public struct ProvenanceSessionLifecycleRequest: Codable, Equatable, Sendable {
    /// Observed lifecycle phase.
    public let phase: ProvenanceSessionLifecyclePhase

    /// Stable session identifier, when the producer already owns one.
    public let sessionID: String?

    /// Parent session identifier, when this session belongs to a known parent.
    public let parentSessionID: String?

    /// Agent runtime kind, such as `codex`, `claude`, or `ci`.
    public let agentKind: String

    /// Client workspace identifier, when known.
    public let workspaceID: String?

    /// Client surface identifier, when known.
    public let surfaceID: String?

    /// Worktree this session operated in, when known.
    public let worktreeID: String?

    /// Session working directory, when known.
    public let workingDirectory: String?

    /// External identity kind for the session, when known.
    public let externalIdentityKind: String?

    /// External identity value for the session, when known.
    public let externalIdentityValue: String?

    /// Optional display label supplied by the producer.
    public let displayName: String?

    /// Time the lifecycle transition was observed.
    public let timestamp: Date

    /// Creates a normalized session lifecycle request.
    public init(
        phase: ProvenanceSessionLifecyclePhase,
        sessionID: String? = nil,
        parentSessionID: String? = nil,
        agentKind: String,
        workspaceID: String? = nil,
        surfaceID: String? = nil,
        worktreeID: String? = nil,
        workingDirectory: String? = nil,
        externalIdentityKind: String? = nil,
        externalIdentityValue: String? = nil,
        displayName: String? = nil,
        timestamp: Date
    ) {
        self.phase = phase
        self.sessionID = sessionID
        self.parentSessionID = parentSessionID
        self.agentKind = agentKind
        self.workspaceID = workspaceID
        self.surfaceID = surfaceID
        self.worktreeID = worktreeID
        self.workingDirectory = workingDirectory
        self.externalIdentityKind = externalIdentityKind
        self.externalIdentityValue = externalIdentityValue
        self.displayName = displayName
        self.timestamp = timestamp
    }
}
