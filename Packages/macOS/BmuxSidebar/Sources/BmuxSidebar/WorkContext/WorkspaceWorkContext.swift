/// Unified work context for a workspace or panel.
public struct WorkspaceWorkContext: Equatable, Sendable {
    /// The git branch associated with the work, when known.
    public let branch: WorkspaceWorkContextBranch?

    /// The repository remote associated with the work, when known.
    public let repositoryRemote: WorkspaceWorkContextRepositoryRemote?

    /// The pull request associated with the work, when known.
    public let pullRequest: WorkspaceWorkContextPullRequest?

    /// The ticket or issue associated with the work, when known.
    public let ticket: WorkspaceWorkContextTicket?

    /// Creates a unified work context.
    /// - Parameters:
    ///   - branch: The git branch associated with the work, when known.
    ///   - repositoryRemote: The repository remote associated with the work, when known.
    ///   - pullRequest: The pull request associated with the work, when known.
    ///   - ticket: The ticket or issue associated with the work, when known.
    public init(
        branch: WorkspaceWorkContextBranch? = nil,
        repositoryRemote: WorkspaceWorkContextRepositoryRemote? = nil,
        pullRequest: WorkspaceWorkContextPullRequest? = nil,
        ticket: WorkspaceWorkContextTicket? = nil
    ) {
        self.branch = branch
        self.repositoryRemote = repositoryRemote
        self.pullRequest = pullRequest
        self.ticket = ticket
    }

    /// Creates a work context from the existing sidebar branch and pull-request state.
    /// - Parameters:
    ///   - sidebarBranch: The existing sidebar branch state, when known.
    ///   - sidebarPullRequest: The existing sidebar pull-request state, when known.
    ///   - branchSource: The source to assign to the projected branch.
    ///   - pullRequestSource: The source to assign to the projected pull request.
    public init(
        sidebarBranch: SidebarGitBranchState?,
        sidebarPullRequest: SidebarPullRequestState?,
        branchSource: WorkspaceWorkContextSource = .sidebarMetadata,
        pullRequestSource: WorkspaceWorkContextSource = .sidebarMetadata
    ) {
        let branch = sidebarBranch.map {
            WorkspaceWorkContextBranch(
                name: $0.branch,
                isDirty: $0.isDirty,
                source: branchSource
            )
        }
        self.init(
            branch: branch,
            pullRequest: sidebarPullRequest.map {
                WorkspaceWorkContextPullRequest(
                    number: $0.number,
                    title: $0.title,
                    label: $0.label,
                    url: $0.url,
                    ownerLogin: $0.ownerLogin,
                    ownerURL: $0.ownerURL,
                    status: $0.status,
                    branch: $0.branch,
                    source: pullRequestSource,
                    isStale: $0.isStale || Self.pullRequestIsStale(
                        sidebarBranch: sidebarBranch,
                        pullRequestBranch: $0.branch
                    )
                )
            },
            ticket: branch.flatMap {
                WorkspaceWorkContextTicket(
                    branchName: $0.name,
                    isStale: $0.isStale
                )
            }
        )
    }

    /// A pure request for resolving a pull request from this context's repository and branch.
    public var pullRequestLookupRequest: WorkspaceWorkContextPullRequestLookupRequest? {
        WorkspaceWorkContextPullRequestLookupRequest(
            repositoryRemote: repositoryRemote,
            branch: branch
        )
    }

    private static func pullRequestIsStale(
        sidebarBranch: SidebarGitBranchState?,
        pullRequestBranch: String?
    ) -> Bool {
        guard let branch = sidebarBranch?.branch.normalizedSidebarBranchName,
              let pullRequestBranch = pullRequestBranch?.normalizedSidebarBranchName else {
            return false
        }
        return branch != pullRequestBranch
    }
}
