/// A pure lookup request for resolving a pull request from repository and branch context.
public struct WorkspaceWorkContextPullRequestLookupRequest: Equatable, Sendable {
    /// The repository remote to use for lookup.
    public let repositoryRemote: WorkspaceWorkContextRepositoryRemote

    /// The normalized branch name to look up.
    public let branch: String

    /// Where this lookup request came from.
    public let source: WorkspaceWorkContextSource

    /// Creates a pull-request lookup request from explicit repository and branch context.
    /// - Parameters:
    ///   - repositoryRemote: The repository remote to use for lookup.
    ///   - branch: The branch to look up.
    ///   - source: Where this lookup request came from.
    public init?(
        repositoryRemote: WorkspaceWorkContextRepositoryRemote,
        branch: String,
        source: WorkspaceWorkContextSource = .gitBranchReport
    ) {
        guard repositoryRemote.slug?.normalizedSidebarBranchName != nil ||
              repositoryRemote.url != nil else {
            return nil
        }
        guard let normalizedBranch = branch.normalizedSidebarBranchName else {
            return nil
        }
        self.repositoryRemote = repositoryRemote
        self.branch = normalizedBranch
        self.source = source
    }

    /// Creates a pull-request lookup request from a unified work context.
    /// - Parameters:
    ///   - repositoryRemote: The repository remote from the work context.
    ///   - branch: The branch from the work context.
    ///   - source: Where this lookup request came from.
    public init?(
        repositoryRemote: WorkspaceWorkContextRepositoryRemote?,
        branch: WorkspaceWorkContextBranch?,
        source: WorkspaceWorkContextSource = .gitBranchReport
    ) {
        guard let repositoryRemote,
              repositoryRemote.isStale == false,
              let branch,
              branch.isStale == false else {
            return nil
        }
        self.init(
            repositoryRemote: repositoryRemote,
            branch: branch.name,
            source: source
        )
    }
}
