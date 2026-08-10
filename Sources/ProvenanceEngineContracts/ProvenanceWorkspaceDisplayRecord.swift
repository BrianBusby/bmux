import Foundation

/// Current-state projection for user-facing workspace display metadata.
public struct ProvenanceWorkspaceDisplayRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable projection identifier.
    public let id: String

    /// Client workspace identifier.
    public let workspaceID: String

    /// Linked repository identifier, when known.
    public let repositoryID: String?

    /// Linked worktree identifier, when known.
    public let worktreeID: String?

    /// Current workspace directory, when accepted from deterministic observation.
    public let currentDirectory: String?

    /// Current display title, when explicitly observed.
    public let title: String?

    /// Source of the current display title, such as `user`, `auto_prompt`, or `auto_summary`.
    public let titleSource: String?

    /// Current branch label shown for the workspace, when known.
    public let branch: String?

    /// Current pull request number, when known.
    public let pullRequestNumber: Int?

    /// Current pull request URL, when known.
    public let pullRequestURL: String?

    /// Current pull request lifecycle status, such as `open`, `merged`, or `closed`.
    public let pullRequestStatus: String?

    /// Pull request head branch, when known.
    public let pullRequestBranch: String?

    /// Whether pull request metadata is known to be stale.
    public let pullRequestIsStale: Bool

    /// Accepted dirty/clean state for the workspace worktree, when known.
    public let isDirty: Bool?

    /// External ticket identifiers linked to the workspace, such as Linear or Jira keys.
    public let ticketIDs: [String]

    /// Durable event ID whose payload last updated this projection.
    public let latestEventID: String?

    /// Append-order ledger sequence whose payload last updated this projection.
    public let latestEventSequence: Int?

    /// Time the display facts were observed.
    public let observedAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a workspace display projection record.
    public init(
        id: String,
        workspaceID: String,
        repositoryID: String? = nil,
        worktreeID: String? = nil,
        currentDirectory: String? = nil,
        title: String? = nil,
        titleSource: String? = nil,
        branch: String? = nil,
        pullRequestNumber: Int? = nil,
        pullRequestURL: String? = nil,
        pullRequestStatus: String? = nil,
        pullRequestBranch: String? = nil,
        pullRequestIsStale: Bool = false,
        isDirty: Bool? = nil,
        ticketIDs: [String] = [],
        latestEventID: String? = nil,
        latestEventSequence: Int? = nil,
        observedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.repositoryID = repositoryID
        self.worktreeID = worktreeID
        self.currentDirectory = currentDirectory
        self.title = title
        self.titleSource = titleSource
        self.branch = branch
        self.pullRequestNumber = pullRequestNumber
        self.pullRequestURL = pullRequestURL
        self.pullRequestStatus = pullRequestStatus
        self.pullRequestBranch = pullRequestBranch
        self.pullRequestIsStale = pullRequestIsStale
        self.isDirty = isDirty
        self.ticketIDs = ticketIDs
        self.latestEventID = latestEventID
        self.latestEventSequence = latestEventSequence
        self.observedAt = observedAt
        self.updatedAt = updatedAt
    }
}
