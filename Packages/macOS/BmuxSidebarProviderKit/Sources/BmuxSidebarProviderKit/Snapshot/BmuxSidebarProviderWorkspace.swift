import Foundation

/// Workspace model exposed to in-process sidebar providers.
public struct BmuxSidebarProviderWorkspace: Identifiable, Codable, Equatable, Sendable {
    /// Workspace id.
    public var id: UUID
    /// Display title.
    public var title: String
    /// Optional custom description.
    public var customDescription: String?
    /// Whether the workspace is pinned.
    public var isPinned: Bool
    /// Workspace root path.
    public var rootPath: String?
    /// Project root path.
    public var projectRootPath: String?
    /// Current git branch summary.
    public var branchSummary: String?
    /// Remote target label, if connected to a remote backend.
    public var remoteDisplayTarget: String?
    /// Remote connection state label.
    public var remoteConnectionState: String?
    /// Unread event count.
    public var unreadCount: Int
    /// Latest notification text.
    public var latestNotificationText: String?
    /// Latest submitted prompt text.
    public var latestSubmittedMessage: String?
    /// Timestamp for the latest submitted prompt.
    public var latestSubmittedAt: Date?
    /// Listening ports detected in the workspace.
    public var listeningPorts: [Int]
    /// Pull request URLs associated with the workspace.
    public var pullRequestURLs: [String]
    /// Pull requests associated with the workspace.
    public var pullRequests: [BmuxSidebarProviderPullRequest]
    /// Panel working directories associated with the workspace.
    public var panelDirectories: [String]
    /// Git branches detected in workspace panel directories.
    public var gitBranches: [BmuxSidebarProviderGitBranch]

    /// Creates a provider workspace snapshot.
    public init(
        id: UUID,
        title: String,
        customDescription: String?,
        isPinned: Bool,
        rootPath: String?,
        projectRootPath: String?,
        branchSummary: String?,
        remoteDisplayTarget: String?,
        remoteConnectionState: String?,
        unreadCount: Int,
        latestNotificationText: String?,
        latestSubmittedMessage: String? = nil,
        latestSubmittedAt: Date? = nil,
        listeningPorts: [Int],
        pullRequestURLs: [String] = [],
        pullRequests: [BmuxSidebarProviderPullRequest] = [],
        panelDirectories: [String] = [],
        gitBranches: [BmuxSidebarProviderGitBranch] = []
    ) {
        self.id = id
        self.title = title
        self.customDescription = customDescription
        self.isPinned = isPinned
        self.rootPath = rootPath
        self.projectRootPath = projectRootPath
        self.branchSummary = branchSummary
        self.remoteDisplayTarget = remoteDisplayTarget
        self.remoteConnectionState = remoteConnectionState
        self.unreadCount = unreadCount
        self.latestNotificationText = latestNotificationText
        self.latestSubmittedMessage = latestSubmittedMessage
        self.latestSubmittedAt = latestSubmittedAt
        self.listeningPorts = listeningPorts
        self.pullRequestURLs = pullRequestURLs.isEmpty ? pullRequests.map(\.url) : pullRequestURLs
        self.pullRequests = pullRequests
        self.panelDirectories = panelDirectories
        self.gitBranches = gitBranches
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        customDescription = try container.decodeIfPresent(String.self, forKey: .customDescription)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        rootPath = try container.decodeIfPresent(String.self, forKey: .rootPath)
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath)
        branchSummary = try container.decodeIfPresent(String.self, forKey: .branchSummary)
        remoteDisplayTarget = try container.decodeIfPresent(String.self, forKey: .remoteDisplayTarget)
        remoteConnectionState = try container.decodeIfPresent(String.self, forKey: .remoteConnectionState)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        latestNotificationText = try container.decodeIfPresent(String.self, forKey: .latestNotificationText)
        latestSubmittedMessage = try container.decodeIfPresent(String.self, forKey: .latestSubmittedMessage)
        latestSubmittedAt = try container.decodeIfPresent(Date.self, forKey: .latestSubmittedAt)
        listeningPorts = try container.decode([Int].self, forKey: .listeningPorts)
        pullRequests = try container.decodeIfPresent([BmuxSidebarProviderPullRequest].self, forKey: .pullRequests) ?? []
        pullRequestURLs = try container.decodeIfPresent([String].self, forKey: .pullRequestURLs) ?? pullRequests.map(\.url)
        panelDirectories = try container.decodeIfPresent([String].self, forKey: .panelDirectories) ?? []
        gitBranches = try container.decodeIfPresent([BmuxSidebarProviderGitBranch].self, forKey: .gitBranches) ?? []
    }
}
