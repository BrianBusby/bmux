import Foundation

/// Current-state projection for one agent session.
struct WorkProvenanceSessionRecord: Codable, Equatable, Sendable, Identifiable {
    /// Native agent session identifier.
    let id: String

    /// Agent kind, such as `codex` or `claude`.
    let agentKind: String

    /// Bmux workspace identifier, when known.
    let workspaceID: String?

    /// Bmux surface identifier, when known.
    let surfaceID: String?

    /// Worktree the session most recently operated in, when known.
    let worktreeID: String?

    /// Current or launch working directory, when known.
    let cwd: String?

    /// Lifecycle status such as `active`, `paused`, `completed`, or `interrupted`.
    let status: String

    /// First observed time.
    let startedAt: Date?

    /// Last projection update time.
    let updatedAt: Date

    /// Creates a session projection record.
    init(
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
