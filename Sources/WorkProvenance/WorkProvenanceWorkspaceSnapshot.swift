import Foundation

/// Sendable workspace state needed by work provenance observation.
struct WorkProvenanceWorkspaceSnapshot: Equatable, Sendable {
    /// Sendable pull-request display metadata captured from workspace state.
    struct PullRequest: Equatable, Sendable {
        let number: Int
        let title: String?
        let url: String
        let ownerLogin: String?
        let ownerURL: String?
        let status: String
        let branch: String?
        let isStale: Bool

        init(
            number: Int,
            title: String? = nil,
            url: String,
            ownerLogin: String?,
            ownerURL: String?,
            status: String,
            branch: String?,
            isStale: Bool
        ) {
            self.number = number
            self.title = title
            self.url = url
            self.ownerLogin = ownerLogin
            self.ownerURL = ownerURL
            self.status = status
            self.branch = branch
            self.isStale = isStale
        }
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

    /// Durable current-work summary displayed for the workspace, when known.
    let currentWorkSummary: String?

    /// Durable submitted prompt display text for the workspace, when known.
    let lastSubmittedPrompt: String?

    /// Submission timestamp for `lastSubmittedPrompt`, when known.
    let lastSubmittedPromptSubmittedAt: Date?

    /// PE field names that were explicitly cleared by a workspace metadata mutation.
    let explicitlyClearedFields: [String]

    /// Creates a workspace snapshot.
    init(
        workspaceID: UUID,
        stableWorkspaceID: UUID,
        title: String,
        titleSource: String? = nil,
        currentDirectory: String,
        branch: String? = nil,
        pullRequest: PullRequest? = nil,
        currentWorkSummary: String? = nil,
        lastSubmittedPrompt: String? = nil,
        lastSubmittedPromptSubmittedAt: Date? = nil,
        explicitlyClearedFields: [String] = []
    ) {
        self.workspaceID = workspaceID
        self.stableWorkspaceID = stableWorkspaceID
        self.title = title
        self.titleSource = titleSource
        self.currentDirectory = currentDirectory
        self.branch = branch
        self.pullRequest = pullRequest
        self.currentWorkSummary = currentWorkSummary
        self.lastSubmittedPrompt = lastSubmittedPrompt
        self.lastSubmittedPromptSubmittedAt = lastSubmittedPromptSubmittedAt
        self.explicitlyClearedFields = explicitlyClearedFields
    }

    /// Creates a workspace snapshot from the live workspace model.
    @MainActor
    init(workspace: Workspace) {
        let branch = workspace.gitBranch?.branch
        let pullRequest = workspace.provenancePullRequestSnapshot()
        let currentWorkSummary = workspace.progress?.label
        let lastSubmittedPrompt = workspace.latestSubmittedMessage
        var explicitlyClearedFields = Set(workspace.workspaceDisplayExplicitClearedFields)
        var knownFields: [String] = []
        if branch != nil {
            explicitlyClearedFields.remove("branch")
            knownFields.append("branch")
        }
        if pullRequest != nil {
            explicitlyClearedFields.remove("pull_request")
            knownFields.append("pull_request")
        }
        if currentWorkSummary != nil {
            explicitlyClearedFields.remove("current_work_summary")
            knownFields.append("current_work_summary")
        }
        if lastSubmittedPrompt != nil {
            explicitlyClearedFields.remove("last_submitted_prompt")
            knownFields.append("last_submitted_prompt")
        }
        workspace.markWorkspaceDisplayFieldsKnown(knownFields)
        self.init(
            workspaceID: workspace.id,
            stableWorkspaceID: workspace.stableId,
            title: workspace.customTitle ?? workspace.title,
            titleSource: workspace.effectiveCustomTitleSource?.rawValue,
            currentDirectory: workspace.currentDirectory,
            branch: branch,
            pullRequest: pullRequest,
            currentWorkSummary: currentWorkSummary,
            lastSubmittedPrompt: lastSubmittedPrompt,
            lastSubmittedPromptSubmittedAt: workspace.latestSubmittedAt,
            explicitlyClearedFields: explicitlyClearedFields.sorted()
        )
    }
}

extension WorkProvenanceWorkspaceSnapshot.PullRequest {
    func replacingOwner(login: String?, url: String?) -> Self {
        Self(
            number: number,
            title: title,
            url: self.url,
            ownerLogin: login,
            ownerURL: url,
            status: status,
            branch: branch,
            isStale: isStale
        )
    }
}

private extension Workspace {
    func provenancePullRequestSnapshot() -> WorkProvenanceWorkspaceSnapshot.PullRequest? {
        let state = pullRequest ?? sidebarPullRequestsInDisplayOrder().first
        guard let state else { return nil }
        return WorkProvenanceWorkspaceSnapshot.PullRequest(
            number: state.number,
            title: state.title,
            url: state.url.absoluteString,
            ownerLogin: state.ownerLogin,
            ownerURL: state.ownerURL?.absoluteString,
            status: state.status.rawValue,
            branch: state.branch,
            isStale: state.isStale
        )
    }
}
