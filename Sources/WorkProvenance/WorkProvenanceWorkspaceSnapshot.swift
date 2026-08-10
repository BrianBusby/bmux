import Foundation

/// Sendable workspace state needed by work provenance observation.
struct WorkProvenanceWorkspaceSnapshot: Equatable, Sendable {
    /// Sendable pull-request display metadata captured from workspace state.
    struct PullRequest: Equatable, Sendable {
        let number: Int
        let url: String
        let ownerLogin: String?
        let ownerURL: String?
        let status: String
        let branch: String?
        let isStale: Bool
    }

    /// Runtime workspace identifier.
    let workspaceID: UUID

    /// Restart-stable workspace identifier.
    let stableWorkspaceID: UUID

    /// Workspace title at observation time.
    let title: String

    /// Source that supplied the current workspace title, when known.
    let titleSource: String?

    /// Workspace current directory at observation time.
    let currentDirectory: String

    /// Branch displayed for the workspace, when known.
    let branch: String?

    /// Pull request displayed for the workspace, when known.
    let pullRequest: PullRequest?

    /// Creates a workspace snapshot.
    init(
        workspaceID: UUID,
        stableWorkspaceID: UUID,
        title: String,
        titleSource: String? = nil,
        currentDirectory: String,
        branch: String? = nil,
        pullRequest: PullRequest? = nil
    ) {
        self.workspaceID = workspaceID
        self.stableWorkspaceID = stableWorkspaceID
        self.title = title
        self.titleSource = titleSource
        self.currentDirectory = currentDirectory
        self.branch = branch
        self.pullRequest = pullRequest
    }

    /// Creates a workspace snapshot from the live workspace model.
    @MainActor
    init(workspace: Workspace) {
        self.init(
            workspaceID: workspace.id,
            stableWorkspaceID: workspace.stableId,
            title: workspace.customTitle ?? workspace.title,
            titleSource: workspace.effectiveCustomTitleSource?.rawValue,
            currentDirectory: workspace.currentDirectory,
            branch: workspace.gitBranch?.branch,
            pullRequest: workspace.provenancePullRequestSnapshot()
        )
    }
}

private extension Workspace {
    func provenancePullRequestSnapshot() -> WorkProvenanceWorkspaceSnapshot.PullRequest? {
        let state = pullRequest ?? sidebarPullRequestsInDisplayOrder().first
        guard let state else { return nil }
        return WorkProvenanceWorkspaceSnapshot.PullRequest(
            number: state.number,
            url: state.url.absoluteString,
            ownerLogin: state.ownerLogin,
            ownerURL: state.ownerURL?.absoluteString,
            status: state.status.rawValue,
            branch: state.branch,
            isStale: state.isStale
        )
    }
}
