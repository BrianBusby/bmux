public import Foundation

/// A pull request associated with workspace work context.
public struct WorkspaceWorkContextPullRequest: Equatable, Sendable {
    /// The pull-request number.
    public let number: Int

    /// The repository label or display label associated with the pull request.
    public let label: String

    /// The pull-request URL.
    public let url: URL

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
    ///   - status: The pull-request lifecycle status.
    ///   - branch: The branch associated with the pull request, when known.
    ///   - source: Where this pull-request value came from.
    ///   - isStale: Whether the value may no longer match the active work.
    public init(
        number: Int,
        label: String,
        url: URL,
        status: SidebarPullRequestStatus,
        branch: String?,
        source: WorkspaceWorkContextSource,
        isStale: Bool = false
    ) {
        self.number = number
        self.label = label
        self.url = url
        self.status = status
        self.branch = branch?.normalizedSidebarBranchName
        self.source = source
        self.isStale = isStale
    }
}
