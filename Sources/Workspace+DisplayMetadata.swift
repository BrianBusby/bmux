import BmuxSidebar
import Foundation

extension Notification.Name {
    static let workspaceDisplayMetadataDidChange = Notification.Name("bmux.workspaceDisplayMetadataDidChange")
}

extension Workspace {
    func postWorkspaceDisplayMetadataDidChange() {
        NotificationCenter.default.post(
            name: .workspaceDisplayMetadataDidChange,
            object: self,
            userInfo: ["workspaceId": id]
        )
    }

    func updatePanelGitBranch(panelId: UUID, branch: String, isDirty: Bool) {
        let state = SidebarGitBranchState(branch: branch, isDirty: isDirty)
        let existing = panelGitBranches[panelId]
        let branchChanged = existing?.branch.normalizedSidebarBranchName != state.branch.normalizedSidebarBranchName
        var displayMetadataChanged = false
        if existing?.branch != branch || existing?.isDirty != isDirty {
            panelGitBranches[panelId] = state
            markWorkspaceDisplayFieldsKnown(["branch"])
            displayMetadataChanged = true
        }
        if branchChanged {
            let nextBranch = state.branch.normalizedSidebarBranchName
            if let pullRequestBranch = panelPullRequests[panelId]?.branch?.normalizedSidebarBranchName,
               pullRequestBranch != nextBranch {
                panelPullRequests.removeValue(forKey: panelId)
                markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
                displayMetadataChanged = true
            }
            if panelId == focusedPanelId,
               let focusedPullRequestBranch = pullRequest?.branch?.normalizedSidebarBranchName,
               focusedPullRequestBranch != nextBranch {
                pullRequest = nil
                markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
                displayMetadataChanged = true
            }
        }
        if panelId == focusedPanelId, gitBranch != state {
            gitBranch = state
            displayMetadataChanged = true
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearPanelGitBranch(panelId: UUID) {
        var displayMetadataChanged = false
        if panelGitBranches[panelId] != nil {
            panelGitBranches.removeValue(forKey: panelId)
            displayMetadataChanged = true
        }
        if panelPullRequests[panelId] != nil {
            panelPullRequests.removeValue(forKey: panelId)
            displayMetadataChanged = true
        }
        if panelId == focusedPanelId {
            if gitBranch != nil {
                gitBranch = nil
                markWorkspaceDisplayFieldsExplicitlyCleared(["branch"])
                displayMetadataChanged = true
            }
            if pullRequest != nil {
                pullRequest = nil
                markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
                displayMetadataChanged = true
            }
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func updatePanelPullRequest(
        panelId: UUID,
        number: Int,
        label: String,
        url: URL,
        ownerLogin: String? = nil,
        ownerURL: URL? = nil,
        status: SidebarPullRequestStatus,
        branch: String? = nil,
        isStale: Bool = false,
        bindToCurrentBranch: Bool = true,
        source: WorkspaceWorkContextSource = .sidebarMetadata
    ) {
        let existing = panelPullRequests[panelId]
        let normalizedBranch = branch?.normalizedSidebarBranchName
        let currentPanelBranch = panelGitBranches[panelId]?.branch.normalizedSidebarBranchName
        let isSameExistingPullRequest = existing?.number == number && existing?.url == url
        let resolvedOwnerLogin = ownerLogin ?? (isSameExistingPullRequest ? existing?.ownerLogin : nil)
        let resolvedOwnerURL = ownerURL ?? (isSameExistingPullRequest ? existing?.ownerURL : nil)
        let resolvedBranch: String? = {
            if let normalizedBranch {
                return normalizedBranch
            }
            if bindToCurrentBranch, let currentPanelBranch {
                return currentPanelBranch
            }
            guard let existing,
                  existing.number == number,
                  existing.label == label,
                  existing.url == url,
                  existing.status == status else {
                return nil
            }
            return existing.branch
        }()
        let state = SidebarPullRequestState(
            number: number,
            label: label,
            url: url,
            ownerLogin: resolvedOwnerLogin,
            ownerURL: resolvedOwnerURL,
            status: status,
            branch: resolvedBranch,
            isStale: isStale
        )
        var displayMetadataChanged = false
        if existing != state {
            markWorkspaceDisplayFieldsKnown(["pull_request"])
            sidebarMetadata.updatePanelPullRequest(state, panelId: panelId, source: source)
            displayMetadataChanged = true
        } else {
            sidebarMetadata.updatePanelPullRequestSource(panelId: panelId, source: source)
        }
        if panelId == focusedPanelId, pullRequest != state {
            sidebarMetadata.updatePullRequest(state, source: source)
            displayMetadataChanged = true
        } else if panelId == focusedPanelId {
            sidebarMetadata.updatePullRequestSource(source)
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearPanelPullRequest(panelId: UUID) {
        var displayMetadataChanged = false
        if panelPullRequests[panelId] != nil {
            panelPullRequests.removeValue(forKey: panelId)
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if panelId == focusedPanelId, pullRequest != nil {
            pullRequest = nil
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearSidebarPullRequestMetadata() {
        var displayMetadataChanged = false
        if !panelPullRequests.isEmpty {
            panelPullRequests.removeAll()
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if pullRequest != nil {
            pullRequest = nil
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearSidebarGitMetadata() {
        var displayMetadataChanged = false
        if !panelGitBranches.isEmpty {
            panelGitBranches.removeAll()
            markWorkspaceDisplayFieldsExplicitlyCleared(["branch"])
            displayMetadataChanged = true
        }
        if !panelPullRequests.isEmpty {
            panelPullRequests.removeAll()
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if pullRequest != nil {
            pullRequest = nil
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if gitBranch != nil {
            gitBranch = nil
            markWorkspaceDisplayFieldsExplicitlyCleared(["branch"])
            displayMetadataChanged = true
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func resetSidebarContext(reason: String = "unspecified") {
        let hadDisplayMetadata = gitBranch != nil
            || !panelGitBranches.isEmpty
            || pullRequest != nil
            || !panelPullRequests.isEmpty
            || progress != nil
            || latestSubmittedMessage != nil
        statusEntries.removeAll()
        clearAllAgentPIDs(refreshPorts: false)
        clearAllAgentLifecycleStates()
        agentListeningPorts.removeAll()
        clearRecordedPromptMessages()
        logEntries.removeAll()
        sidebarMetadata.progress = nil
        markWorkspaceDisplayFieldsExplicitlyCleared([
            "current_work_summary",
            "last_submitted_prompt",
        ])
        gitBranch = nil
        panelGitBranches.removeAll()
        pullRequest = nil
        panelPullRequests.removeAll()
        surfaceListeningPorts.removeAll()
        listeningPorts.removeAll()
        metadataBlocks.removeAll()
        resetBrowserPanelsForContextChange(reason: reason)
        if hadDisplayMetadata {
            postWorkspaceDisplayMetadataDidChange()
        }
    }
}
