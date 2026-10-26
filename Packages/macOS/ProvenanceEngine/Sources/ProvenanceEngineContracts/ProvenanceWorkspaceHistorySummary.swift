import Foundation

/// Observed session history for one restart-stable workspace identity.
public struct ProvenanceWorkspaceHistorySummary: Codable, Equatable, Sendable, Identifiable {
    /// Restart-stable workspace identity.
    public let id: String
    /// Earliest observed session start, when known.
    public let firstSessionAt: Date?
    /// Most recent verified session activity, when known.
    public let lastActivityAt: Date?
    /// Number of distinct retained sessions linked to this workspace.
    public let sessionCount: Int
    /// Working directory of the most recently active linked session, when known.
    public let lastKnownDirectory: String?
    /// Repository identity linked to the most recently active session's worktree, when known.
    public let lastKnownRepositoryID: String?
    /// Last observed workspace display facts, when available.
    public let display: ProvenanceWorkspaceDisplayRecord?

    /// Creates a historical workspace summary from observed sessions.
    ///
    /// - Parameters:
    ///   - id: Restart-stable workspace identity.
    ///   - firstSessionAt: Earliest observed session start.
    ///   - lastActivityAt: Most recent verified work activity.
    ///   - sessionCount: Number of distinct linked sessions.
    ///   - lastKnownDirectory: Last observed session working directory.
    ///   - lastKnownRepositoryID: Repository linked to the last observed worktree.
    ///   - display: Last observed workspace display facts.
    public init(id: String, firstSessionAt: Date?, lastActivityAt: Date?, sessionCount: Int,
                lastKnownDirectory: String? = nil,
                lastKnownRepositoryID: String? = nil,
                display: ProvenanceWorkspaceDisplayRecord? = nil) {
        self.id = id
        self.firstSessionAt = firstSessionAt
        self.lastActivityAt = lastActivityAt
        self.sessionCount = sessionCount
        self.lastKnownDirectory = lastKnownDirectory
        self.lastKnownRepositoryID = lastKnownRepositoryID
        self.display = display
    }
}
