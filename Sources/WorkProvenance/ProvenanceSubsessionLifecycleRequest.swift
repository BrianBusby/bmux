import Foundation

/// Request to record one normalized child-session lifecycle transition.
struct ProvenanceSubsessionLifecycleRequest: Codable, Equatable, Sendable {
    /// Observed lifecycle phase.
    let phase: ProvenanceSubsessionLifecyclePhase

    /// Parent session that owns the child session.
    let parentSessionID: String

    /// Agent runtime kind, such as `codex` or `claude`.
    let agentKind: String

    /// Client workspace identifier, when known.
    let workspaceID: String?

    /// Client surface identifier, when known.
    let surfaceID: String?

    /// Child session working directory, when known.
    let workingDirectory: String?

    /// External identity kind for the child session, when known.
    let externalIdentityKind: String?

    /// External identity value for the child session, when known.
    let externalIdentityValue: String?

    /// Optional display label supplied by the client adapter.
    let displayName: String?

    /// Time the lifecycle transition was observed.
    let timestamp: Date

    /// Creates a normalized subsession lifecycle request.
    init(
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
