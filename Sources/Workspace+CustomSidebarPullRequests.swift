import BmuxSwiftRender
import Foundation

extension Workspace {
    /// Pull-request values projected for the custom-sidebar interpreter
    /// context (`workspaces[i].pr` / `workspaces[i].prs`). Reads the per-panel
    /// pull-request state in sidebar display order plus PE-owned display
    /// current state rather than the focused-panel `pullRequest` mirror: the
    /// mirror only refreshes while its panel is focused, so it is routinely nil
    /// for background workspaces that do have a known open PR.
    func customSidebarPullRequestValues(
        provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot? = nil
    ) -> [SwiftValue] {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: sidebarPullRequestsInDisplayOrder(),
            provenancePullRequest: provenanceDisplaySnapshot?.pullRequest,
            provenanceCurrentDirectory: provenanceDisplaySnapshot?.currentDirectory,
            provenanceBranch: provenanceDisplaySnapshot?.branch,
            latestSubmittedMessage: provenanceDisplaySnapshot?.lastSubmittedPrompt ?? latestSubmittedMessage,
            latestConversationMessage: latestConversationMessage,
            label: String(localized: "sidebar.pullRequest.label", defaultValue: "PR")
        )
        return rows.compactMap { pullRequest in
            guard let url = pullRequest.url else { return nil }
            var fields: [String: SwiftValue] = [
                "number": .int(pullRequest.number),
                "label": .string(pullRequest.label),
                "url": .string(url.absoluteString),
                "status": .string(pullRequest.status.rawValue),
                "stale": .bool(pullRequest.isStale),
            ]
            if let ownerLogin = pullRequest.ownerLogin { fields["owner"] = .string(ownerLogin) }
            if let ownerURL = pullRequest.ownerURL {
                fields["owner_url"] = .string(ownerURL.absoluteString)
            }
            if let branch = pullRequest.branch { fields["branch"] = .string(branch) }
            return .object(fields)
        }
    }
}
