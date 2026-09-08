import BmuxGit
import BmuxSidebarGit
import Foundation

@MainActor
struct TabManagerSidebarGitPullRequestObservationServices {
    let sidebarGitMetadataService: any SidebarGitMetadataServing
    let pullRequestProbing: any PullRequestProbing
    let attachesHostFromTabManager: Bool
    let isCompatibilityReporter: Bool
    let refreshSubmittedPullRequestMention: (TabManager, UUID, SubmittedPromptPullRequestRecord) -> Void
    let cancelSubmittedPullRequestMentionRefreshes: () -> Void

    static func compatibilityReporter() -> TabManagerSidebarGitPullRequestObservationServices {
        let pullRequestReporter = SidebarPullRequestCompatibilityReporter()
        let gitReporter = SidebarGitMetadataCompatibilityReporter(pullRequestProbing: pullRequestReporter)
        return TabManagerSidebarGitPullRequestObservationServices(
            sidebarGitMetadataService: gitReporter,
            pullRequestProbing: pullRequestReporter,
            attachesHostFromTabManager: true,
            isCompatibilityReporter: true,
            refreshSubmittedPullRequestMention: { _, _, _ in },
            cancelSubmittedPullRequestMentionRefreshes: {}
        )
    }

    static func runtimeOwned(
        facade: any SidebarGitMetadataServing & PullRequestProbing,
        refreshSubmittedPullRequestMention: @escaping (TabManager, UUID, SubmittedPromptPullRequestRecord) -> Void,
        cancelSubmittedPullRequestMentionRefreshes: @escaping () -> Void
    ) -> TabManagerSidebarGitPullRequestObservationServices {
        TabManagerSidebarGitPullRequestObservationServices(
            sidebarGitMetadataService: facade,
            pullRequestProbing: facade,
            attachesHostFromTabManager: false,
            isCompatibilityReporter: false,
            refreshSubmittedPullRequestMention: refreshSubmittedPullRequestMention,
            cancelSubmittedPullRequestMentionRefreshes: cancelSubmittedPullRequestMentionRefreshes
        )
    }

}

@MainActor
private final class SidebarGitMetadataCompatibilityReporter: SidebarGitMetadataServing {
    private weak var host: (any SidebarGitHosting)?
    private let pullRequestProbing: any PullRequestProbing

    init(pullRequestProbing: any PullRequestProbing) {
        self.pullRequestProbing = pullRequestProbing
    }

    func attach(host: any SidebarGitHosting) {
        self.host = host
    }

    func scheduleInitialWorkspaceGitMetadataRefreshIfPossible(workspaceId: UUID, panelId: UUID, reason: String) {}

    func updateSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        guard let host, host.workspaceExists(workspaceId) else { return }
        let normalized = directory.normalizedGitProbeDirectory
        guard host.updatePanelDirectory(
            workspaceId: workspaceId,
            panelId: panelId,
            directory: normalized,
            displayLabel: displayLabel
        ) else { return }
        if !host.isGitMetadataWatchEnabled {
            clearSurfaceGitBranch(workspaceId: workspaceId, panelId: panelId)
        }
    }

    func updateRemoteSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        guard let host, host.workspaceExists(workspaceId) else { return }
        let normalized = directory.normalizedGitProbeDirectory
        guard host.updateRemotePanelDirectory(
            workspaceId: workspaceId,
            panelId: panelId,
            directory: normalized,
            displayLabel: displayLabel
        ) else { return }
        if !host.isGitMetadataWatchEnabled || host.isRemoteWorkspace(workspaceId) == true {
            clearSurfaceGitBranch(workspaceId: workspaceId, panelId: panelId)
        }
    }

    func updateSurfaceGitBranch(workspaceId: UUID, panelId: UUID, branch: String, isDirty: Bool?) {
        guard let host, host.workspaceExists(workspaceId) else { return }
        guard host.isGitMetadataWatchEnabled else {
            clearSurfaceGitBranch(workspaceId: workspaceId, panelId: panelId)
            return
        }
        let current = host.panelGitBranch(workspaceId: workspaceId, panelId: panelId)
        let normalizedBranch = GitMetadataService.normalizedBranchName(branch) ?? branch
        let nextIsDirty = isDirty ?? (current?.branch == normalizedBranch ? current?.isDirty ?? false : false)
        guard current?.branch != normalizedBranch || current?.isDirty != nextIsDirty else { return }
        host.updatePanelGitBranch(
            workspaceId: workspaceId,
            panelId: panelId,
            branch: normalizedBranch,
            isDirty: nextIsDirty
        )
    }

    func clearSurfaceGitBranch(workspaceId: UUID, panelId: UUID) {
        guard let host, host.workspaceExists(workspaceId) else { return }
        if host.panelGitBranch(workspaceId: workspaceId, panelId: panelId) != nil {
            host.clearPanelGitBranch(workspaceId: workspaceId, panelId: panelId)
        }
        if host.panelPullRequestBadge(workspaceId: workspaceId, panelId: panelId) != nil {
            host.clearPanelPullRequest(workspaceId: workspaceId, panelId: panelId)
        }
        pullRequestProbing.clearWorkspacePullRequestTracking(workspaceId: workspaceId, panelId: panelId)
    }

    func refreshTrackedWorkspaceGitMetadata(reason: String) {}

    func sidebarGitMetadataWatchSettingsDidChange() {
        guard let host, !host.isGitMetadataWatchEnabled else { return }
        host.clearAllSidebarGitMetadata()
        pullRequestProbing.resetWorkspacePullRequestRefreshState()
    }

    func stopSidebarGitMetadataObservation() {
        host = nil
    }

    func clearWorkspaceGitProbes(workspaceId: UUID) {
        pullRequestProbing.clearWorkspacePullRequestTracking(workspaceId: workspaceId)
    }

    func resetAllWorkspaceGitProbeTracking() {
        pullRequestProbing.resetWorkspacePullRequestRefreshState()
    }

    func trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: UUID) -> Set<UUID> { [] }

    func activeWorkspaceGitProbePanelIds(workspaceId: UUID) -> Set<UUID> { [] }
}

@MainActor
private final class SidebarPullRequestCompatibilityReporter: PullRequestProbing {
    private weak var host: (any SidebarGitHosting)?

    func attach(host: any SidebarGitHosting) {
        self.host = host
    }

    func scheduleWorkspacePullRequestRefresh(workspaceId: UUID, panelId: UUID, reason: String) {
        guard host?.isPullRequestPollingEnabled == false else { return }
        host?.clearPanelPullRequest(workspaceId: workspaceId, panelId: panelId)
    }

    func refreshTrackedWorkspacePullRequestsIfNeeded(reason: String) {}

    func sidebarPullRequestPollingSettingsDidChange() {
        guard let host, !host.isPullRequestPollingEnabled else { return }
        host.clearAllSidebarPullRequestMetadata()
    }

    func stopWorkspacePullRequestObservation() {
        host = nil
    }

    func handleWorkspacePullRequestCommandHint(workspaceId: UUID, panelId: UUID, action: String, target: String?) {
        guard let host, host.workspaceExists(workspaceId) else { return }
        guard host.isPullRequestPollingEnabled else {
            host.clearPanelPullRequest(workspaceId: workspaceId, panelId: panelId)
            return
        }
        guard let currentPullRequest = host.panelPullRequestBadge(workspaceId: workspaceId, panelId: panelId),
              Self.targetMatchesCurrentPullRequest(target, currentPullRequest: currentPullRequest) else {
            return
        }
        let nextStatus: PullRequestStatus
        switch action {
        case "merge":
            guard currentPullRequest.status == .open else { return }
            nextStatus = .merged
        case "close":
            guard currentPullRequest.status == .open else { return }
            nextStatus = .closed
        case "reopen":
            guard currentPullRequest.status != .open else { return }
            nextStatus = .open
        default:
            return
        }
        host.updatePanelPullRequest(
            workspaceId: workspaceId,
            panelId: panelId,
            badge: SidebarPullRequestBadge(
                number: currentPullRequest.number,
                title: currentPullRequest.title,
                label: currentPullRequest.label,
                url: currentPullRequest.url,
                ownerLogin: currentPullRequest.ownerLogin,
                ownerURL: currentPullRequest.ownerURL,
                status: nextStatus,
                branch: currentPullRequest.branch,
                isStale: false
            )
        )
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID, panelId: UUID) {}

    func clearWorkspacePullRequestMetadata(workspaceId: UUID, panelId: UUID) {
        host?.clearPanelPullRequest(workspaceId: workspaceId, panelId: panelId)
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID) {}

    func resetWorkspacePullRequestRefreshState() {}

    func workspacePullRequestTrackedPanelIds(workspaceId: UUID) -> Set<UUID> { [] }

    private static func targetMatchesCurrentPullRequest(
        _ rawTarget: String?,
        currentPullRequest: SidebarPullRequestBadge
    ) -> Bool {
        let trimmedTarget = rawTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTarget.isEmpty else { return true }

        let numberToken = trimmedTarget.hasPrefix("#") ? String(trimmedTarget.dropFirst()) : trimmedTarget
        if let number = Int(numberToken), number == currentPullRequest.number {
            return true
        }

        if let targetURL = URL(string: trimmedTarget) {
            if targetURL == currentPullRequest.url {
                return true
            }
            if let lastComponent = targetURL.pathComponents.last,
               let number = Int(lastComponent),
               number == currentPullRequest.number {
                return true
            }
        }

        return GitMetadataService.normalizedBranchName(trimmedTarget) == GitMetadataService.normalizedBranchName(currentPullRequest.branch)
    }
}
