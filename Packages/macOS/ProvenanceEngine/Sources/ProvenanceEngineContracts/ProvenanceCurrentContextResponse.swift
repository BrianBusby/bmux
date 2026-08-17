import Foundation

/// Bounded domain response for a current provenance context query.
public struct ProvenanceCurrentContextResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether a provenance worktree was found for the requested path.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Absolute worktree root path requested by the caller.
    public let repositoryPath: String

    /// Current-state worktree projection, when found.
    public let worktree: ProvenanceWorktreeRecord?

    /// Linked repository projection, when available.
    public let repository: ProvenanceRepositoryRecord?

    /// Bounded active sessions in query order.
    public let activeSessions: [ProvenanceCurrentContextSession]

    /// Bounded dirty file changes in query order.
    public let dirtyFiles: [ProvenanceCurrentContextFileChange]

    /// Bounded unattributed file changes in query order.
    public let unattributedChanges: [ProvenanceCurrentContextFileChange]

    /// Bounded recent checkpoints in query order.
    public let recentCheckpoints: [ProvenanceCurrentContextCheckpoint]

    /// Bounded validation runs in query order.
    public let validationRuns: [ProvenanceCurrentContextValidationRun]

    /// Bounded potential contribution conflicts in query order.
    public let conflicts: [ProvenanceCurrentContextConflict]

    /// Creates a current-context response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        repositoryPath: String,
        worktree: ProvenanceWorktreeRecord?,
        repository: ProvenanceRepositoryRecord?,
        activeSessions: [ProvenanceCurrentContextSession],
        dirtyFiles: [ProvenanceCurrentContextFileChange],
        unattributedChanges: [ProvenanceCurrentContextFileChange],
        recentCheckpoints: [ProvenanceCurrentContextCheckpoint],
        validationRuns: [ProvenanceCurrentContextValidationRun],
        conflicts: [ProvenanceCurrentContextConflict]
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.repositoryPath = repositoryPath
        self.worktree = worktree
        self.repository = repository
        self.activeSessions = activeSessions
        self.dirtyFiles = dirtyFiles
        self.unattributedChanges = unattributedChanges
        self.recentCheckpoints = recentCheckpoints
        self.validationRuns = validationRuns
        self.conflicts = conflicts
    }
}
