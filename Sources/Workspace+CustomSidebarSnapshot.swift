import BmuxSidebar
import Foundation

extension Workspace {
    /// Projects live workspace state into the custom-sidebar interpreter input snapshot.
    func customSidebarWorkspaceSnapshot(
        index: Int,
        selectedId: UUID?,
        unreadCount: Int
    ) -> CustomSidebarWorkspaceSnapshot {
        let focusedPanelId = focusedPanelId
        let firstBranch = sidebarGitBranchesInDisplayOrder().first
        let provenanceDisplaySnapshot = owningTabManager?.workProvenanceRuntime?
            .workspaceDisplayCurrentStateSnapshot(for: self)
        let progress = self.progress.map {
            CustomSidebarWorkspaceSnapshot.Progress(value: $0.value, label: $0.label)
        }
        let remote = remoteDisplayTarget.map { target in
            CustomSidebarWorkspaceSnapshot.Remote(
                target: target,
                stateRawValue: remoteConnectionState.rawValue,
                isConnected: remoteConnectionState == .connected
            )
        }
        return CustomSidebarWorkspaceSnapshot(
            id: id,
            title: customTitle ?? provenanceDisplaySnapshot?.title ?? title,
            isSelected: id == selectedId,
            isPinned: isPinned,
            index: index,
            directory: presentedCurrentDirectory ?? "",
            listeningPorts: listeningPorts,
            unreadCount: unreadCount,
            surfaces: customSidebarSurfaceSnapshots(focusedPanelId: focusedPanelId),
            surfaceCount: bonsplitController.allPaneIds.reduce(0) {
                $0 + bonsplitController.tabs(inPane: $1).count
            },
            customDescription: customDescription,
            customColor: customColor,
            gitBranch: provenanceDisplaySnapshot?.branch ?? firstBranch?.branch,
            gitIsDirty: provenanceDisplaySnapshot?.branch != nil
                ? provenanceDisplaySnapshot?.isDirty == true
                : firstBranch?.isDirty ?? false,
            pullRequestValues: customSidebarPullRequestValues(
                provenanceDisplaySnapshot: provenanceDisplaySnapshot
            ),
            progress: progress,
            latestConversationMessage: latestConversationMessage,
            latestSubmittedMessage: provenanceDisplaySnapshot?.lastSubmittedPrompt ?? latestSubmittedMessage,
            latestSubmittedAt: provenanceDisplaySnapshot?.lastSubmittedPromptSubmittedAt ?? latestSubmittedAt,
            remote: remote
        )
    }

    private func customSidebarSurfaceSnapshots(focusedPanelId: UUID?) -> [CustomSidebarSurfaceSnapshot] {
        var surfaces: [CustomSidebarSurfaceSnapshot] = []
        for paneId in bonsplitController.allPaneIds {
            for tab in bonsplitController.tabs(inPane: paneId) {
                guard let panelId = panelIdFromSurfaceId(tab.id) else { continue }
                let git = reportedPanelGitBranch(panelId: panelId)
                surfaces.append(
                    CustomSidebarSurfaceSnapshot(
                        panelId: panelId,
                        title: tab.title,
                        isFocused: panelId == focusedPanelId,
                        isPinned: pinnedPanelIds.contains(panelId),
                        directory: reportedPanelDirectory(panelId: panelId),
                        gitBranch: git?.branch,
                        gitIsDirty: git?.isDirty ?? false,
                        listeningPorts: surfaceListeningPorts[panelId] ?? []
                    )
                )
            }
        }
        return surfaces
    }
}
