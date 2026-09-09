import BmuxSidebarGit
import Foundation

@MainActor
final class SidebarGitPullRequestObservationRuntimeFacade: SidebarGitMetadataServing, PullRequestProbing {
    private weak var runtime: SidebarGitPullRequestObservationRuntimeService?

    init(runtime: SidebarGitPullRequestObservationRuntimeService) {
        self.runtime = runtime
    }

    func attach(host: any SidebarGitHosting) {}

    func scheduleInitialWorkspaceGitMetadataRefreshIfPossible(workspaceId: UUID, panelId: UUID, reason: String) {
        runtime?.scheduleInitialWorkspaceGitMetadataRefreshIfPossible(
            workspaceId: workspaceId,
            panelId: panelId,
            reason: reason
        )
    }

    func updateSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        runtime?.updateSurfaceDirectory(
            workspaceId: workspaceId,
            panelId: panelId,
            directory: directory,
            displayLabel: displayLabel
        )
    }

    func updateRemoteSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        runtime?.updateRemoteSurfaceDirectory(
            workspaceId: workspaceId,
            panelId: panelId,
            directory: directory,
            displayLabel: displayLabel
        )
    }

    func updateSurfaceGitBranch(workspaceId: UUID, panelId: UUID, branch: String, isDirty: Bool?) {
        runtime?.updateSurfaceGitBranch(
            workspaceId: workspaceId,
            panelId: panelId,
            branch: branch,
            isDirty: isDirty
        )
    }

    func clearSurfaceGitBranch(workspaceId: UUID, panelId: UUID) {
        runtime?.clearSurfaceGitBranch(workspaceId: workspaceId, panelId: panelId)
    }

    func refreshTrackedWorkspaceGitMetadata(reason: String) {
        runtime?.refreshTrackedWorkspaceGitMetadata(reason: reason)
    }

    func sidebarGitMetadataWatchSettingsDidChange() {
        runtime?.sidebarGitMetadataWatchSettingsDidChange()
    }

    func stopSidebarGitMetadataObservation() {}

    func clearWorkspaceGitProbes(workspaceId: UUID) {
        runtime?.clearWorkspaceGitProbes(workspaceId: workspaceId)
    }

    func resetAllWorkspaceGitProbeTracking() {
        runtime?.resetAllWorkspaceGitProbeTracking()
    }

    func trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: UUID) -> Set<UUID> {
        runtime?.trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: workspaceId) ?? []
    }

    func activeWorkspaceGitProbePanelIds(workspaceId: UUID) -> Set<UUID> {
        runtime?.activeWorkspaceGitProbePanelIds(workspaceId: workspaceId) ?? []
    }

    func scheduleWorkspacePullRequestRefresh(workspaceId: UUID, panelId: UUID, reason: String) {
        runtime?.scheduleWorkspacePullRequestRefresh(workspaceId: workspaceId, panelId: panelId, reason: reason)
    }

    func refreshTrackedWorkspacePullRequestsIfNeeded(reason: String) {
        runtime?.refreshTrackedWorkspacePullRequestsIfNeeded(reason: reason)
    }

    func sidebarPullRequestPollingSettingsDidChange() {
        runtime?.sidebarPullRequestPollingSettingsDidChange()
    }

    func stopWorkspacePullRequestObservation() {}

    func handleWorkspacePullRequestCommandHint(workspaceId: UUID, panelId: UUID, action: String, target: String?) {
        runtime?.handleWorkspacePullRequestCommandHint(
            workspaceId: workspaceId,
            panelId: panelId,
            action: action,
            target: target
        )
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID, panelId: UUID) {
        runtime?.clearWorkspacePullRequestTracking(workspaceId: workspaceId, panelId: panelId)
    }

    func clearWorkspacePullRequestMetadata(workspaceId: UUID, panelId: UUID) {
        runtime?.clearWorkspacePullRequestMetadata(workspaceId: workspaceId, panelId: panelId)
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID) {
        runtime?.clearWorkspacePullRequestTracking(workspaceId: workspaceId)
    }

    func resetWorkspacePullRequestRefreshState() {
        runtime?.resetWorkspacePullRequestRefreshState()
    }

    func workspacePullRequestTrackedPanelIds(workspaceId: UUID) -> Set<UUID> {
        runtime?.workspacePullRequestTrackedPanelIds(workspaceId: workspaceId) ?? []
    }
}
