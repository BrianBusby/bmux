import Foundation
import BmuxSidebarGit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
extension TabManager {
    func refreshTrackedWorkspaceGitMetadataForTesting() {
        sidebarGitMetadataService.refreshTrackedWorkspaceGitMetadata(reason: "test")
    }

    func trackedWorkspaceGitMetadataPollCandidatePanelIdsForTesting(workspaceId: UUID) -> Set<UUID> {
        sidebarGitMetadataService.trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: workspaceId)
    }

    func activeWorkspaceGitProbePanelIdsForTesting(workspaceId: UUID) -> Set<UUID> {
        sidebarGitMetadataService.activeWorkspaceGitProbePanelIds(workspaceId: workspaceId)
    }

    func workspacePullRequestTrackedPanelIdsForTesting(workspaceId: UUID) -> Set<UUID> {
        var panelIds = pullRequestProbing.workspacePullRequestTrackedPanelIds(workspaceId: workspaceId)
        if let workspace = tabs.first(where: { $0.id == workspaceId }) {
            panelIds.formUnion(workspace.panelPullRequests.keys)
        }
        return panelIds
    }

    func clearWorkspaceGitProbesForTesting(workspaceId: UUID) {
        sidebarGitMetadataService.clearWorkspaceGitProbes(workspaceId: workspaceId)
    }
}

extension MobileHostDeferralPolicy {
    static let disabledForSidebarGitTests = MobileHostDeferralPolicy(deferralInterval: 0, quietInterval: 0)
}

@MainActor
func waitForMainActorCondition(
    timeout: TimeInterval = 3.0,
    pollInterval: TimeInterval = 0.02,
    _ condition: @escaping () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
    }
    return condition()
}
