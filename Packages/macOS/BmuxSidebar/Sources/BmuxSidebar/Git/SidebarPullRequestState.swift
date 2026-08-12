public import Foundation

/// One pull-request row shown under a workspace in the sidebar.
public struct SidebarPullRequestState: Equatable, Sendable {
    /// The PR number.
    public let number: Int
    /// The PR title, if known.
    public let title: String?
    /// The repository label (e.g. `owner/repo`).
    public let label: String
    /// The PR URL.
    public let url: URL
    /// The PR author's GitHub login, if known.
    public let ownerLogin: String?
    /// The PR author's GitHub profile URL, if known.
    public let ownerURL: URL?
    /// Lifecycle status.
    public let status: SidebarPullRequestStatus
    /// The PR's branch, normalized (trimmed, nil when empty).
    public let branch: String?
    /// Whether the row is stale (reported by an inactive panel).
    public let isStale: Bool

    /// Creates a pull-request row (defaults mirror the legacy initializer).
    public init(
        number: Int,
        title: String? = nil,
        label: String,
        url: URL,
        ownerLogin: String? = nil,
        ownerURL: URL? = nil,
        status: SidebarPullRequestStatus,
        branch: String? = nil,
        isStale: Bool = false
    ) {
        self.number = number
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.title = normalizedTitle.isEmpty ? nil : normalizedTitle
        self.label = label
        self.url = url
        let normalizedOwnerLogin = ownerLogin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.ownerLogin = normalizedOwnerLogin.isEmpty ? nil : normalizedOwnerLogin
        self.ownerURL = ownerURL
        self.status = status
        self.branch = branch?.normalizedSidebarBranchName
        self.isStale = isStale
    }
}
