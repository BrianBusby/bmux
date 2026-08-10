public import Foundation

/// A pull request associated with workspace work context.
public struct WorkspaceWorkContextPullRequest: Equatable, Sendable {
    /// The pull-request number.
    public let number: Int

    /// The repository label or display label associated with the pull request.
    public let label: String

    /// The pull-request URL.
    public let url: URL

    /// The PR author's GitHub login, if known.
    public let ownerLogin: String?

    /// The PR author's GitHub profile URL, if known.
    public let ownerURL: URL?

    /// The pull-request lifecycle status.
    public let status: SidebarPullRequestStatus

    /// The branch associated with the pull request, when known.
    public let branch: String?

    /// Where this pull-request value came from.
    public let source: WorkspaceWorkContextSource

    /// Whether the pull-request value may no longer match the active work.
    public let isStale: Bool

    /// Creates a pull-request context.
    /// - Parameters:
    ///   - number: The pull-request number.
    ///   - label: The repository or display label.
    ///   - url: The pull-request URL.
    ///   - ownerLogin: The PR author's GitHub login, if known.
    ///   - ownerURL: The PR author's GitHub profile URL, if known.
    ///   - status: The pull-request lifecycle status.
    ///   - branch: The branch associated with the pull request, when known.
    ///   - source: Where this pull-request value came from.
    ///   - isStale: Whether the value may no longer match the active work.
    public init(
        number: Int,
        label: String,
        url: URL,
        ownerLogin: String? = nil,
        ownerURL: URL? = nil,
        status: SidebarPullRequestStatus,
        branch: String?,
        source: WorkspaceWorkContextSource,
        isStale: Bool = false
    ) {
        self.number = number
        self.label = label
        self.url = url
        let normalizedOwnerLogin = ownerLogin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.ownerLogin = normalizedOwnerLogin.isEmpty ? nil : normalizedOwnerLogin
        self.ownerURL = ownerURL
        self.status = status
        self.branch = branch?.normalizedSidebarBranchName
        self.source = source
        self.isStale = isStale
    }
}
