import Combine
import BmuxCore
import Foundation
import BmuxSidebar
import BmuxWorkspaces
import SwiftUI

private struct SidebarPanelObservationState: Equatable {
    let panelIds: [UUID]

    init(panels: [UUID: any Panel]) {
        panelIds = panels.keys.sorted { $0.uuidString < $1.uuidString }
    }
}

extension View {
    func sidebarAgentRuntimeObservation(
        id: UUID,
        model: WorkspaceSidebarAgentRuntimeObservationModel,
        onChange: @MainActor @escaping () -> Void
    ) -> some View {
        task(id: id) { @MainActor in
            for await _ in model.changes() {
                if Task.isCancelled { break }
                onChange()
            }
        }
    }
}

private struct SidebarObservationState: Equatable {
    let currentDirectory: String
    let extensionSidebarProjectRootPath: String?
    let panels: SidebarPanelObservationState
    let panelDirectories: [UUID: String]
    let panelDirectoryDisplayLabels: [UUID: String]
    let directoryChangeRevision: UInt64
    let statusEntries: [String: SidebarStatusEntry]
    let metadataBlocks: [String: SidebarMetadataBlock]
    let logEntries: [SidebarLogEntry]
    let progress: SidebarProgressState?
    let gitBranch: SidebarGitBranchState?
    let panelGitBranches: [UUID: SidebarGitBranchState]
    let pullRequest: SidebarPullRequestState?
    let panelPullRequests: [UUID: SidebarPullRequestState]
    let remoteConfiguration: WorkspaceRemoteConfiguration?
    let remoteConnectionState: WorkspaceRemoteConnectionState
    let remoteConnectionDetail: String?
    let activeRemoteTerminalSessionCount: Int
    let listeningPorts: [Int]
    let panelShellActivityStates: [UUID: PanelShellActivityState]
    let agentPIDKeysByPanelId: [UUID: Set<String>]
    let agentLifecycleStatesByPanelId: [UUID: [String: AgentHibernationLifecycleState]]
    let agentSessionProviderActivity: [UUID: Bool]
    let interruptedAgentWorkPanelIds: Set<UUID>
    let browserMediaActivity: BrowserMediaActivity
}

extension Workspace {
    // Leading-edge coalescing for the immediate sidebar observation stream.
    // Every subscription (a sidebar row, the MergeMany extension-sidebar
    // aggregate) fires a full makeWorkspaceSnapshot() rebuild per emission.
    // Agents (e.g. Codex) rewrite a workspace title every turn, and
    // removeDuplicates() cannot collapse distinct titles, so without coalescing
    // each rewrite drives a snapshot rebuild per consumer per workspace.
    // `sidebarImmediateObservationChangeSubject` is sent from didSet hooks,
    // after @Published storage has the new value; using $title/$latestSubmitted
    // directly would deliver willSet events and let row snapshots read stale
    // workspace fields. coalesceLatest keeps the first change in a burst
    // synchronous (a user pin/color/title edit stays immediate, which Combine's
    // throttle cannot guarantee because it schedules every emission onto the
    // scheduler) and collapses the tail of the burst into one trailing emission
    // per window.
    // See https://github.com/manaflow-ai/bmux/issues/4127.
    static let sidebarImmediateObservationCoalesceInterval: RunLoop.SchedulerTimeType.Stride = .milliseconds(50)

    func makeSidebarImmediateObservationPublisher() -> AnyPublisher<Void, Never> {
        sidebarImmediateObservationChangeSubject
            .prepend(())
            .coalesceLatest(
                for: Self.sidebarImmediateObservationCoalesceInterval,
                scheduler: RunLoop.main
            )
            .eraseToAnyPublisher()
    }

    /// Merged immediate observation across workspaces for the extension
    /// sidebar. Coalesced again across the merge: per-workspace coalescing
    /// caps each stream, but N workspaces bursting concurrently would still
    /// re-render the whole extension sidebar once per workspace per window.
    /// The leading edge stays synchronous, so a lone change is as immediate
    /// as before.
    static func mergedImmediateObservationPublisher(for workspaces: [Workspace]) -> AnyPublisher<Void, Never> {
        Publishers.MergeMany(workspaces.map { $0.sidebarImmediateObservationPublisher })
            .receive(on: RunLoop.main)
            .coalesceLatest(
                for: sidebarImmediateObservationCoalesceInterval,
                scheduler: RunLoop.main
            )
            .eraseToAnyPublisher()
    }

    func makeSidebarObservationPublisher() -> AnyPublisher<Void, Never> {
        let workspaceFields = Publishers.CombineLatest4(
            $currentDirectory,
            $extensionSidebarProjectRootPath,
            panelsPublisher.map(SidebarPanelObservationState.init),
            $panelDirectories
        )
        let metadataFields = Publishers.CombineLatest4(
            sidebarMetadata.statusEntriesPublisher,
            sidebarMetadata.metadataBlocksPublisher,
            sidebarMetadata.logEntriesPublisher,
            sidebarMetadata.progressPublisher
        )
        let gitFields = Publishers.CombineLatest4(
            sidebarMetadata.gitBranchPublisher,
            sidebarMetadata.panelGitBranchesPublisher,
            sidebarMetadata.pullRequestPublisher,
            sidebarMetadata.panelPullRequestsPublisher
        )
        let remoteFields = Publishers.CombineLatest4(
            $remoteConfiguration,
            $remoteConnectionState,
            $remoteConnectionDetail,
            $activeRemoteTerminalSessionCount
        )
        let terminalAgentFields = Publishers.CombineLatest4(
            panelShellActivityStatesPublisher,
            agentPIDKeysByPanelIdPublisher,
            agentLifecycleStatesByPanelIdPublisher,
            agentSessionActiveWorkPublisher
        )
        .combineLatest(interruptedAgentWorkPanelIdsPublisher)
        let directoryChangeRevision = currentDirectoryChangeRevisionPublisher()
        return Publishers.CombineLatest4(
            workspaceFields,
            metadataFields,
            gitFields,
            remoteFields
        )
            .combineLatest($listeningPorts, sidebarMetadata.panelDirectoryDisplayLabelsPublisher)
            .combineLatest(terminalAgentFields)
            .combineLatest(directoryChangeRevision)
            .compactMap { [weak self] values, directoryChangeRevision -> SidebarObservationState? in
                guard let self else { return nil }
                let (groupedFieldsAndTerminalFields, directoryChangeRevision) = (values, directoryChangeRevision)
                let (groupedFieldsAndDirectoryLabels, terminalAgentFields) = groupedFieldsAndTerminalFields
                let (groupedFields, listeningPorts, panelDirectoryDisplayLabels) = groupedFieldsAndDirectoryLabels
                let workspaceFields = groupedFields.0
                let metadataFields = groupedFields.1
                let gitFields = groupedFields.2
                let remoteFields = groupedFields.3
                let terminalAgentStateFields = terminalAgentFields.0
                let interruptedAgentWorkPanelIds = terminalAgentFields.1
                let panelShellActivityStates = terminalAgentStateFields.0
                let agentPIDKeysByPanelId = terminalAgentStateFields.1
                let agentLifecycleStatesByPanelId = terminalAgentStateFields.2
                let agentSessionActiveWork = terminalAgentStateFields.3
                return SidebarObservationState(
                    currentDirectory: workspaceFields.0,
                    extensionSidebarProjectRootPath: workspaceFields.1,
                    panels: workspaceFields.2,
                    panelDirectories: workspaceFields.3,
                    panelDirectoryDisplayLabels: panelDirectoryDisplayLabels,
                    directoryChangeRevision: directoryChangeRevision,
                    statusEntries: metadataFields.0,
                    metadataBlocks: metadataFields.1,
                    logEntries: metadataFields.2,
                    progress: metadataFields.3,
                    gitBranch: gitFields.0,
                    panelGitBranches: gitFields.1,
                    pullRequest: gitFields.2,
                    panelPullRequests: gitFields.3,
                    remoteConfiguration: remoteFields.0,
                    remoteConnectionState: remoteFields.1,
                    remoteConnectionDetail: remoteFields.2,
                    activeRemoteTerminalSessionCount: remoteFields.3,
                    listeningPorts: listeningPorts,
                    panelShellActivityStates: panelShellActivityStates,
                    agentPIDKeysByPanelId: agentPIDKeysByPanelId,
                    agentLifecycleStatesByPanelId: agentLifecycleStatesByPanelId,
                    agentSessionProviderActivity: agentSessionActiveWork,
                    interruptedAgentWorkPanelIds: interruptedAgentWorkPanelIds,
                    browserMediaActivity: self.browserMediaActivity
                )
            }
            .removeDuplicates()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
