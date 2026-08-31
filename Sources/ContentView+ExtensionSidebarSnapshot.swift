import BmuxSidebar
import BmuxSidebarProviderKit
import Foundation

extension VerticalTabsSidebar {
    func extensionSidebarSnapshot(workspaces: [Workspace]) -> BmuxSidebarProviderSnapshot {
        BmuxSidebarProviderSnapshot(
            sequence: UInt64(max(0, BmuxEventBus.shared.latestSequence)),
            selectedWorkspaceId: tabManager.selectedTabId,
            workspaces: workspaces.map(extensionWorkspaceSnapshot(for:)),
            windowId: windowId
        )
    }

    func extensionWorkspaceSnapshot(for workspace: Workspace) -> BmuxSidebarProviderWorkspace {
        let rootPath = extensionSidebarRootPath(for: workspace)
        let orderedPanelIds = workspace.sidebarOrderedPanelIds()
        let provenanceDisplaySnapshot = tabManager.workProvenanceRuntime?
            .workspaceDisplayCurrentStateSnapshot(for: workspace)
        let pullRequestDisplays = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: workspace.sidebarPullRequestsInDisplayOrder(orderedPanelIds: orderedPanelIds),
            provenancePullRequest: provenanceDisplaySnapshot?.pullRequest,
            provenanceCurrentDirectory: provenanceDisplaySnapshot?.currentDirectory,
            provenanceBranch: provenanceDisplaySnapshot?.branch,
            latestSubmittedMessage: provenanceDisplaySnapshot?.lastSubmittedPrompt ?? workspace.latestSubmittedMessage,
            latestConversationMessage: workspace.latestConversationMessage,
            label: String(localized: "sidebar.pullRequest.label", defaultValue: "PR")
        )
        let providerPullRequests: [BmuxSidebarProviderPullRequest] = pullRequestDisplays.compactMap { pullRequest -> BmuxSidebarProviderPullRequest? in
            guard let url = pullRequest.url else { return nil }
            return BmuxSidebarProviderPullRequest(
                number: pullRequest.number,
                title: pullRequest.title,
                label: pullRequest.label,
                url: url.absoluteString,
                status: pullRequest.status.rawValue,
                ownerLogin: pullRequest.ownerLogin,
                ownerURL: pullRequest.ownerURL?.absoluteString,
                branch: pullRequest.branch,
                isStale: pullRequest.isStale
            )
        }
        return BmuxSidebarProviderWorkspace(
            id: workspace.id,
            title: workspace.customTitle ?? provenanceDisplaySnapshot?.title ?? workspace.title,
            customDescription: workspace.customDescription,
            isPinned: workspace.isPinned,
            rootPath: rootPath,
            projectRootPath: workspace.extensionSidebarProjectRootPath,
            branchSummary: provenanceDisplaySnapshot?.branch
                ?? workspace.sidebarGitBranchesInDisplayOrder().first?.branch,
            remoteDisplayTarget: workspace.remoteDisplayTarget,
            remoteConnectionState: workspace.remoteConnectionState.rawValue,
            unreadCount: sidebarUnread.unreadCount(forWorkspaceId: workspace.id),
            latestNotificationText: sidebarUnread.latestNotificationText(forWorkspaceId: workspace.id),
            latestSubmittedMessage: provenanceDisplaySnapshot?.lastSubmittedPrompt ?? workspace.latestSubmittedMessage,
            latestSubmittedAt: provenanceDisplaySnapshot?.lastSubmittedPromptSubmittedAt ?? workspace.latestSubmittedAt,
            listeningPorts: workspace.listeningPorts,
            pullRequestURLs: providerPullRequests.map { $0.url },
            pullRequests: providerPullRequests,
            panelDirectories: workspace.sidebarFilesystemDirectoriesInDisplayOrder(),
            gitBranches: workspace.sidebarGitBranchesInDisplayOrder().map {
                BmuxSidebarProviderGitBranch(branch: $0.branch, isDirty: $0.isDirty)
            }
        )
    }

    func extensionSidebarRootPath(for workspace: Workspace) -> String? {
        workspace.presentedCurrentDirectory?.nilIfEmpty
    }
}
