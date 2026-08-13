import BmuxSidebar
import Foundation

extension Notification.Name {
    static let workspaceDisplayMetadataDidChange = Notification.Name("bmux.workspaceDisplayMetadataDidChange")
}

private extension WorkspaceWorkContextSource {
    var pullRequestEvidenceRank: Int {
        switch self {
        case .manual:
            return 4
        case .promptMention:
            return 3
        case .pullRequestLookup, .gitBranchReport, .branchName:
            return 2
        case .sidebarMetadata, .unknown:
            return 1
        }
    }

    func canReplacePullRequest(from existingSource: WorkspaceWorkContextSource?) -> Bool {
        pullRequestEvidenceRank >= (existingSource ?? .sidebarMetadata).pullRequestEvidenceRank
    }

    func preferredPullRequestSource(over existingSource: WorkspaceWorkContextSource?) -> WorkspaceWorkContextSource {
        guard let existingSource else { return self }
        return existingSource.pullRequestEvidenceRank > pullRequestEvidenceRank ? existingSource : self
    }
}

extension Workspace {
    func postWorkspaceDisplayMetadataDidChange() {
        NotificationCenter.default.post(
            name: .workspaceDisplayMetadataDidChange,
            object: self,
            userInfo: ["workspaceId": id]
        )
    }

    func updateProgressForWorkspaceDisplay(_ newValue: SidebarProgressState?) {
        let oldValue = sidebarMetadata.progress
        sidebarMetadata.progress = newValue
        guard oldValue != newValue else { return }
        if Self.normalizedCustomDescription(newValue?.label) != nil {
            markWorkspaceDisplayFieldsKnown(["current_work_summary"])
        }
        postWorkspaceDisplayMetadataDidChange()
    }

    func sidebarStatusEntriesInDisplayOrder() -> [SidebarStatusEntry] {
        sidebarStatusEntriesVisibleForDisplay().sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp > rhs.timestamp }
            return lhs.key < rhs.key
        }
    }

    func sidebarMetadataBlocksInDisplayOrder() -> [SidebarMetadataBlock] {
        sidebarMetadata.metadataBlocksInDisplayOrder()
    }

    func updatePanelGitBranch(
        panelId: UUID,
        branch: String,
        isDirty: Bool,
        source: WorkspaceWorkContextSource = .gitBranchReport
    ) {
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
               pullRequestBranch != nextBranch,
               source.canReplacePullRequest(from: sidebarMetadata.workContext(panelId: panelId).pullRequest?.source) {
                panelPullRequests.removeValue(forKey: panelId)
                markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
                displayMetadataChanged = true
            }
            if panelId == focusedPanelId,
               let focusedPullRequestBranch = pullRequest?.branch?.normalizedSidebarBranchName,
               focusedPullRequestBranch != nextBranch,
               source.canReplacePullRequest(from: sidebarMetadata.workContext.pullRequest?.source) {
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

    func clearPanelGitBranch(
        panelId: UUID,
        source: WorkspaceWorkContextSource = .manual
    ) {
        var displayMetadataChanged = false
        if panelGitBranches[panelId] != nil {
            panelGitBranches.removeValue(forKey: panelId)
            displayMetadataChanged = true
        }
        if panelPullRequests[panelId] != nil,
           source.canReplacePullRequest(from: sidebarMetadata.workContext(panelId: panelId).pullRequest?.source) {
            panelPullRequests.removeValue(forKey: panelId)
            displayMetadataChanged = true
        }
        if panelId == focusedPanelId {
            if gitBranch != nil {
                gitBranch = nil
                markWorkspaceDisplayFieldsExplicitlyCleared(["branch"])
                displayMetadataChanged = true
            }
            if pullRequest != nil,
               source.canReplacePullRequest(from: sidebarMetadata.workContext.pullRequest?.source) {
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
        title: String? = nil,
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
        let existingSource = sidebarMetadata.workContext(panelId: panelId).pullRequest?.source
        let existingWorkspaceSource = sidebarMetadata.workContext.pullRequest?.source
        let normalizedBranch = branch?.normalizedSidebarBranchName
        let currentPanelBranch = panelGitBranches[panelId]?.branch.normalizedSidebarBranchName
        let isSameExistingPullRequest = existing?.number == number && existing?.url == url
        let isSameWorkspacePullRequest = pullRequest?.number == number && pullRequest?.url == url
        if existing != nil,
           !isSameExistingPullRequest,
           !source.canReplacePullRequest(from: existingSource) {
            return
        }
        if panelId == focusedPanelId,
           pullRequest != nil,
           !isSameWorkspacePullRequest,
           !source.canReplacePullRequest(from: existingWorkspaceSource) {
            return
        }
        let resolvedPanelSource = source.preferredPullRequestSource(over: existingSource)
        let resolvedWorkspaceSource = source.preferredPullRequestSource(over: existingWorkspaceSource)
        let resolvedTitle = title ?? (isSameExistingPullRequest ? existing?.title : nil)
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
            title: resolvedTitle,
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
            sidebarMetadata.updatePanelPullRequest(state, panelId: panelId, source: resolvedPanelSource)
            displayMetadataChanged = true
        } else {
            sidebarMetadata.updatePanelPullRequestSource(panelId: panelId, source: resolvedPanelSource)
        }
        if panelId == focusedPanelId, pullRequest != state {
            sidebarMetadata.updatePullRequest(state, source: resolvedWorkspaceSource)
            displayMetadataChanged = true
        } else if panelId == focusedPanelId {
            sidebarMetadata.updatePullRequestSource(resolvedWorkspaceSource)
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearPanelPullRequest(
        panelId: UUID,
        source: WorkspaceWorkContextSource = .manual
    ) {
        var displayMetadataChanged = false
        if panelPullRequests[panelId] != nil,
           source.canReplacePullRequest(from: sidebarMetadata.workContext(panelId: panelId).pullRequest?.source) {
            panelPullRequests.removeValue(forKey: panelId)
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if panelId == focusedPanelId,
           pullRequest != nil,
           source.canReplacePullRequest(from: sidebarMetadata.workContext.pullRequest?.source) {
            pullRequest = nil
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearSidebarPullRequestMetadata(source: WorkspaceWorkContextSource = .manual) {
        var displayMetadataChanged = false
        let removablePanelIds = panelPullRequests.keys.filter {
            source.canReplacePullRequest(from: sidebarMetadata.workContext(panelId: $0).pullRequest?.source)
        }
        if !removablePanelIds.isEmpty {
            for panelId in removablePanelIds {
                panelPullRequests.removeValue(forKey: panelId)
            }
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if pullRequest != nil,
           source.canReplacePullRequest(from: sidebarMetadata.workContext.pullRequest?.source) {
            pullRequest = nil
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if displayMetadataChanged {
            postWorkspaceDisplayMetadataDidChange()
        }
    }

    func clearSidebarGitMetadata(source: WorkspaceWorkContextSource = .manual) {
        var displayMetadataChanged = false
        if !panelGitBranches.isEmpty {
            panelGitBranches.removeAll()
            markWorkspaceDisplayFieldsExplicitlyCleared(["branch"])
            displayMetadataChanged = true
        }
        let removablePanelIds = panelPullRequests.keys.filter {
            source.canReplacePullRequest(from: sidebarMetadata.workContext(panelId: $0).pullRequest?.source)
        }
        if !removablePanelIds.isEmpty {
            for panelId in removablePanelIds {
                panelPullRequests.removeValue(forKey: panelId)
            }
            markWorkspaceDisplayFieldsExplicitlyCleared(["pull_request"])
            displayMetadataChanged = true
        }
        if pullRequest != nil,
           source.canReplacePullRequest(from: sidebarMetadata.workContext.pullRequest?.source) {
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
