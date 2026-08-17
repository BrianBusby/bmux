import Foundation

/// Current-state projection for one agent session.
public struct ProvenanceSessionRecord: Codable, Equatable, Sendable, Identifiable {
    /// Native agent session identifier.
    public let id: String

    /// Agent kind, such as `codex` or `claude`.
    public let agentKind: String

    /// Client workspace identifier, when known.
    public let workspaceID: String?

    /// Client surface identifier, when known.
    public let surfaceID: String?

    /// Worktree the session most recently operated in, when known.
    public let worktreeID: String?

    /// Current or launch working directory, when known.
    public let cwd: String?

    /// Lifecycle status such as `active`, `paused`, `completed`, or `interrupted`.
    public let status: String

    /// First observed time.
    public let startedAt: Date?

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a session projection record.
    public init(
        id: String,
        agentKind: String,
        workspaceID: String? = nil,
        surfaceID: String? = nil,
        worktreeID: String? = nil,
        cwd: String? = nil,
        status: String,
        startedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.agentKind = agentKind
        self.workspaceID = workspaceID
        self.surfaceID = surfaceID
        self.worktreeID = worktreeID
        self.cwd = cwd
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}
