import Foundation

/// Filter metadata for one workspace with retained session evidence.
public struct ProvenanceWorkspaceHistoryFacet: Codable, Equatable, Sendable {
    /// Restart-stable workspace identity.
    public let workspaceID: String
    /// Most recent verified session activity.
    public let lastActivityAt: Date?
    /// Last known repository identity from display or linked worktree evidence.
    public let repositoryID: String?
    /// Project links accepted for the workspace display.
    public let projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    /// Last accepted pull request owner login.
    public let pullRequestOwnerLogin: String?

    /// Creates filter metadata for retained workspace history.
    ///
    /// - Parameters:
    ///   - workspaceID: Restart-stable workspace identity.
    ///   - lastActivityAt: Most recent verified session activity.
    ///   - repositoryID: Last known repository identity.
    ///   - projectLinks: Accepted project links.
    ///   - pullRequestOwnerLogin: Accepted pull request owner login.
    public init(workspaceID: String, lastActivityAt: Date?, repositoryID: String?,
                projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord],
                pullRequestOwnerLogin: String?) {
        self.workspaceID = workspaceID
        self.lastActivityAt = lastActivityAt
        self.repositoryID = repositoryID
        self.projectLinks = projectLinks
        self.pullRequestOwnerLogin = pullRequestOwnerLogin
    }
}
