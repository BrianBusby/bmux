import Foundation

/// Request to record one normalized child-session lifecycle transition.
public struct ProvenanceSubsessionLifecycleRequest: Codable, Equatable, Sendable {
    /// Observed lifecycle phase.
    public let phase: ProvenanceSubsessionLifecyclePhase

    /// Parent session that owns the child session.
    public let parentSessionID: String

    /// Agent runtime kind, such as `codex` or `claude`.
    public let agentKind: String

    /// Client workspace identifier, when known.
    public let workspaceID: String?

    /// Client surface identifier, when known.
    public let surfaceID: String?

    /// Child session working directory, when known.
    public let workingDirectory: String?

    /// External identity kind for the child session, when known.
    public let externalIdentityKind: String?

    /// External identity value for the child session, when known.
    public let externalIdentityValue: String?

    /// Optional display label supplied by the client adapter.
    public let displayName: String?

    /// Time the lifecycle transition was observed.
    public let timestamp: Date

    /// Creates a normalized subsession lifecycle request.
    public init(
        phase: ProvenanceSubsessionLifecyclePhase,
        parentSessionID: String,
        agentKind: String,
        workspaceID: String? = nil,
        surfaceID: String? = nil,
        workingDirectory: String? = nil,
        externalIdentityKind: String? = nil,
        externalIdentityValue: String? = nil,
        displayName: String? = nil,
        timestamp: Date
    ) {
        self.phase = phase
        self.parentSessionID = parentSessionID
        self.agentKind = agentKind
        self.workspaceID = workspaceID
        self.surfaceID = surfaceID
        self.workingDirectory = workingDirectory
        self.externalIdentityKind = externalIdentityKind
        self.externalIdentityValue = externalIdentityValue
        self.displayName = displayName
        self.timestamp = timestamp
    }
}
