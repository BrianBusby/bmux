import BmuxGit
import BmuxSidebar
import BmuxSidebarGit
import Foundation

@MainActor
final class SidebarGitPullRequestObservationRuntimeService {
    private final class HostSession {
        let id: ObjectIdentifier
        weak var host: (any SidebarGitHosting)?
        let services: SidebarGitPullRequestObservationHostServices
        var workspaceIds: Set<UUID> = []

        init(host: any SidebarGitHosting, services: SidebarGitPullRequestObservationHostServices) {
            self.id = ObjectIdentifier(host)
            self.host = host
            self.services = services
        }
    }

    private struct PromptMentionRefreshKey: Hashable {
        let workspaceId: UUID
        let panelId: UUID
        let number: Int
        let urlString: String
    }

    private struct PromptMentionRefreshWork {
        let generation: UInt64
        let task: Task<Void, Never>
    }

    private let isCapabilityEnabled: Bool
    private let dependencies: SidebarGitPullRequestObservationRuntimeServiceDependencies
    private var didAttemptStart = false
    private var didStart = false
    private var latestStartupResult: SidebarGitPullRequestObservationRuntimeOperationResult = .ready
    private var sessionsByHostId: [ObjectIdentifier: HostSession] = [:]
    private var hostIdsByWorkspaceId: [UUID: ObjectIdentifier] = [:]
    private var promptMentionRefreshGeneration: UInt64 = 0
    private var promptMentionRefreshTasksByKey: [PromptMentionRefreshKey: PromptMentionRefreshWork] = [:]
    private lazy var facade = SidebarGitPullRequestObservationRuntimeFacade(runtime: self)
    private(set) var lifecycleState: SidebarGitPullRequestObservationRuntimeLifecycleState

    init(
        isCapabilityEnabled: Bool,
        dependencies: SidebarGitPullRequestObservationRuntimeServiceDependencies
    ) {
        self.isCapabilityEnabled = isCapabilityEnabled
        self.dependencies = dependencies
        self.lifecycleState = isCapabilityEnabled
            ? .notStarted
            : .disabled(reason: "disabled by composition")
    }

    func tabManagerObservationServices() -> TabManagerSidebarGitPullRequestObservationServices {
        TabManagerSidebarGitPullRequestObservationServices.runtimeOwned(
            facade: facade,
            refreshSubmittedPullRequestMention: { [weak self] tabManager, workspaceId, record in
                self?.refreshSubmittedPullRequestMention(
                    tabManager: tabManager,
                    workspaceId: workspaceId,
                    record: record
                )
            },
            cancelSubmittedPullRequestMentionRefreshes: { [weak self] in
                self?.cancelSubmittedPullRequestMentionRefreshes()
            }
        )
    }

    @discardableResult
    func start(host: any SidebarGitHosting) -> Bool {
        guard isCapabilityEnabled else {
            lifecycleState = .disabled(reason: "disabled by composition")
            return false
        }

        let shouldCountStart = !didAttemptStart
        if !didAttemptStart {
            didAttemptStart = true
            lifecycleState = .starting
            latestStartupResult = dependencies.validateRequiredRuntime()
            switch latestStartupResult {
            case .failed(let reason):
                lifecycleState = .failed(reason: reason)
                return shouldCountStart
            case .disabled(let reason):
                lifecycleState = .disabled(reason: reason)
                return shouldCountStart
            case .ready, .degraded:
                didStart = true
            }
        }

        let wasExistingSession = session(for: host) != nil
        let session = session(for: host) ?? createSession(for: host)
        let previousWorkspaceIds = session.workspaceIds
        refreshWorkspaceRouting(for: session)
        if wasExistingSession {
            let addedWorkspaceIds = session.workspaceIds.subtracting(previousWorkspaceIds)
            reconcileInitialObservation(for: session, workspaceIds: addedWorkspaceIds, reason: "runtimeWorkspaceReconcile")
        } else {
            reconcileInitialObservation(for: session, workspaceIds: session.workspaceIds, reason: "runtimeStart")
        }
        updateLifecycleState(from: latestStartupResult)
        return shouldCountStart
    }

    func detach(host: any SidebarGitHosting, isStillUsed: Bool) {
        guard !isStillUsed else { return }
        let hostId = ObjectIdentifier(host)
        guard let session = sessionsByHostId.removeValue(forKey: hostId) else { return }
        for workspaceId in session.workspaceIds {
            if hostIdsByWorkspaceId[workspaceId] == hostId {
                hostIdsByWorkspaceId.removeValue(forKey: workspaceId)
            }
        }
        cancelSubmittedPullRequestMentionRefreshes(workspaceIds: session.workspaceIds)
        stop(session)
        if didStart {
            updateLifecycleState(from: latestStartupResult)
        }
    }

    func stop() {
        guard hasActiveLifecycleWork || didAttemptStart else {
            if isCapabilityEnabled {
                lifecycleState = .stopped
            }
            return
        }

        lifecycleState = .stopping
        for session in sessionsByHostId.values {
            stop(session)
        }
        cancelSubmittedPullRequestMentionRefreshes()
        sessionsByHostId.removeAll()
        hostIdsByWorkspaceId.removeAll()
        didAttemptStart = false
        didStart = false
        latestStartupResult = .ready
        lifecycleState = .stopped
    }

    var hasActiveLifecycleWork: Bool {
        didStart || !sessionsByHostId.isEmpty
    }

#if DEBUG
    func waitForSubmittedPullRequestMentionRefreshesForTesting() async {
        while true {
            let tasks = promptMentionRefreshTasksByKey.values.map(\.task)
            guard !tasks.isEmpty else { return }
            for task in tasks {
                await task.value
            }
        }
    }
#endif

    // MARK: Facade dispatch

    func scheduleInitialWorkspaceGitMetadataRefreshIfPossible(
        workspaceId: UUID,
        panelId: UUID,
        reason: String
    ) {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService
            .scheduleInitialWorkspaceGitMetadataRefreshIfPossible(
                workspaceId: workspaceId,
                panelId: panelId,
                reason: reason
            )
    }

    func updateSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService.updateSurfaceDirectory(
            workspaceId: workspaceId,
            panelId: panelId,
            directory: directory,
            displayLabel: displayLabel
        )
    }

    func updateRemoteSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService.updateRemoteSurfaceDirectory(
            workspaceId: workspaceId,
            panelId: panelId,
            directory: directory,
            displayLabel: displayLabel
        )
    }

    func updateSurfaceGitBranch(workspaceId: UUID, panelId: UUID, branch: String, isDirty: Bool?) {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService.updateSurfaceGitBranch(
            workspaceId: workspaceId,
            panelId: panelId,
            branch: branch,
            isDirty: isDirty
        )
    }

    func clearSurfaceGitBranch(workspaceId: UUID, panelId: UUID) {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService.clearSurfaceGitBranch(
            workspaceId: workspaceId,
            panelId: panelId
        )
    }

    func refreshTrackedWorkspaceGitMetadata(reason: String) {
        for session in sessionsByHostId.values {
            session.services.sidebarGitMetadataService.refreshTrackedWorkspaceGitMetadata(reason: reason)
        }
    }

    func sidebarGitMetadataWatchSettingsDidChange() {
        for session in sessionsByHostId.values {
            session.services.sidebarGitMetadataService.sidebarGitMetadataWatchSettingsDidChange()
        }
    }

    func clearWorkspaceGitProbes(workspaceId: UUID) {
        guard let session = hostSession(forWorkspaceId: workspaceId) else { return }
        session.services.sidebarGitMetadataService.clearWorkspaceGitProbes(workspaceId: workspaceId)
        hostIdsByWorkspaceId.removeValue(forKey: workspaceId)
        session.workspaceIds.remove(workspaceId)
    }

    func resetAllWorkspaceGitProbeTracking() {
        for session in sessionsByHostId.values {
            session.services.sidebarGitMetadataService.resetAllWorkspaceGitProbeTracking()
        }
    }

    func trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: UUID) -> Set<UUID> {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService
            .trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: workspaceId) ?? []
    }

    func activeWorkspaceGitProbePanelIds(workspaceId: UUID) -> Set<UUID> {
        hostSession(forWorkspaceId: workspaceId)?.services.sidebarGitMetadataService
            .activeWorkspaceGitProbePanelIds(workspaceId: workspaceId) ?? []
    }

    func scheduleWorkspacePullRequestRefresh(workspaceId: UUID, panelId: UUID, reason: String) {
        hostSession(forWorkspaceId: workspaceId)?.services.pullRequestProbing.scheduleWorkspacePullRequestRefresh(
            workspaceId: workspaceId,
            panelId: panelId,
            reason: reason
        )
    }

    func refreshTrackedWorkspacePullRequestsIfNeeded(reason: String) {
        for session in sessionsByHostId.values {
            session.services.pullRequestProbing.refreshTrackedWorkspacePullRequestsIfNeeded(reason: reason)
        }
    }

    func sidebarPullRequestPollingSettingsDidChange() {
        for session in sessionsByHostId.values {
            session.services.pullRequestProbing.sidebarPullRequestPollingSettingsDidChange()
        }
    }

    func handleWorkspacePullRequestCommandHint(
        workspaceId: UUID,
        panelId: UUID,
        action: String,
        target: String?
    ) {
        hostSession(forWorkspaceId: workspaceId)?.services.pullRequestProbing.handleWorkspacePullRequestCommandHint(
            workspaceId: workspaceId,
            panelId: panelId,
            action: action,
            target: target
        )
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID, panelId: UUID) {
        hostSession(forWorkspaceId: workspaceId)?.services.pullRequestProbing.clearWorkspacePullRequestTracking(
            workspaceId: workspaceId,
            panelId: panelId
        )
    }

    func clearWorkspacePullRequestMetadata(workspaceId: UUID, panelId: UUID) {
        hostSession(forWorkspaceId: workspaceId)?.services.pullRequestProbing.clearWorkspacePullRequestMetadata(
            workspaceId: workspaceId,
            panelId: panelId
        )
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID) {
        guard let session = hostSession(forWorkspaceId: workspaceId) else { return }
        session.services.pullRequestProbing.clearWorkspacePullRequestTracking(workspaceId: workspaceId)
    }

    func resetWorkspacePullRequestRefreshState() {
        for session in sessionsByHostId.values {
            session.services.pullRequestProbing.resetWorkspacePullRequestRefreshState()
        }
    }

    func workspacePullRequestTrackedPanelIds(workspaceId: UUID) -> Set<UUID> {
        hostSession(forWorkspaceId: workspaceId)?.services.pullRequestProbing
            .workspacePullRequestTrackedPanelIds(workspaceId: workspaceId) ?? []
    }

    func refreshSubmittedPullRequestMention(
        tabManager: TabManager,
        workspaceId: UUID,
        record: SubmittedPromptPullRequestRecord
    ) {
        guard isCapabilityEnabled, didStart else { return }
        guard hostSession(forWorkspaceId: workspaceId) != nil else { return }
        guard let panelId = record.panelId,
              let mention = record.mention else { return }

        let key = PromptMentionRefreshKey(
            workspaceId: workspaceId,
            panelId: panelId,
            number: mention.number,
            urlString: mention.url.absoluteString
        )
        promptMentionRefreshTasksByKey[key]?.task.cancel()
        promptMentionRefreshGeneration &+= 1
        let generation = promptMentionRefreshGeneration
        let probeService = dependencies.promptMentionProbeService
        let task = Task.detached(priority: .utility) { [weak self, weak tabManager] in
            let pullRequest = await probeService.fetchPromptMentionPullRequest(
                url: mention.url,
                expectedNumber: mention.number
            )
            await MainActor.run { [weak self, weak tabManager] in
                guard let self else { return }
                guard self.promptMentionRefreshTasksByKey[key]?.generation == generation else { return }
                self.promptMentionRefreshTasksByKey.removeValue(forKey: key)
                guard let pullRequest,
                      let status = PullRequestStatus(githubState: pullRequest.state),
                      let resolvedURL = URL(string: pullRequest.url),
                      let tabManager,
                      let workspace = tabManager.tabs.first(where: { $0.id == workspaceId }),
                      workspace.panels[panelId] != nil,
                      let currentPullRequest = workspace.panelPullRequests[panelId],
                      currentPullRequest.number == mention.number,
                      currentPullRequest.url == mention.url else { return }
                workspace.updatePanelPullRequest(
                    panelId: panelId,
                    number: pullRequest.number,
                    title: pullRequest.title,
                    label: currentPullRequest.label,
                    url: resolvedURL,
                    ownerLogin: pullRequest.ownerLogin,
                    ownerURL: Self.promptMentionOwnerURL(
                        explicitURLString: pullRequest.ownerURLString,
                        ownerLogin: pullRequest.ownerLogin
                    ),
                    status: SidebarPullRequestStatus(rawValue: status.rawValue) ?? .open,
                    branch: nil,
                    isStale: false,
                    bindToCurrentBranch: false,
                    source: .promptMention
                )
            }
        }
        promptMentionRefreshTasksByKey[key] = PromptMentionRefreshWork(
            generation: generation,
            task: task
        )
    }

    // MARK: Session management

    private func session(for host: any SidebarGitHosting) -> HostSession? {
        sessionsByHostId[ObjectIdentifier(host)]
    }

    private func createSession(for host: any SidebarGitHosting) -> HostSession {
        let hostServices = dependencies.makeHostServices()
        hostServices.pullRequestProbing.attach(host: host)
        hostServices.sidebarGitMetadataService.attach(host: host)
        let session = HostSession(host: host, services: hostServices)
        sessionsByHostId[session.id] = session
        return session
    }

    private func hostSession(forWorkspaceId workspaceId: UUID) -> HostSession? {
        if let hostId = hostIdsByWorkspaceId[workspaceId],
           let session = sessionsByHostId[hostId],
           session.host?.workspaceExists(workspaceId) == true {
            return session
        }

        for session in sessionsByHostId.values {
            guard session.host?.workspaceExists(workspaceId) == true else { continue }
            refreshWorkspaceRouting(for: session)
            return session
        }

        hostIdsByWorkspaceId.removeValue(forKey: workspaceId)
        return nil
    }

    private func refreshWorkspaceRouting(for session: HostSession) {
        guard let host = session.host else {
            sessionsByHostId.removeValue(forKey: session.id)
            return
        }
        let currentWorkspaceIds = Set(host.orderedWorkspaceIds())
        let removedWorkspaceIds = session.workspaceIds.subtracting(currentWorkspaceIds)
        for workspaceId in removedWorkspaceIds {
            session.services.sidebarGitMetadataService.clearWorkspaceGitProbes(workspaceId: workspaceId)
            session.services.pullRequestProbing.clearWorkspacePullRequestTracking(workspaceId: workspaceId)
            if hostIdsByWorkspaceId[workspaceId] == session.id {
                hostIdsByWorkspaceId.removeValue(forKey: workspaceId)
            }
        }
        session.workspaceIds = currentWorkspaceIds
        for workspaceId in currentWorkspaceIds {
            hostIdsByWorkspaceId[workspaceId] = session.id
        }
    }

    private func reconcileInitialObservation(for session: HostSession, workspaceIds: Set<UUID>, reason: String) {
        guard let host = session.host else { return }
        guard !workspaceIds.isEmpty else { return }
        for workspaceId in host.orderedWorkspaceIds() where workspaceIds.contains(workspaceId) {
            for panelId in host.panelIds(in: workspaceId) where host.hasTerminalPanel(workspaceId: workspaceId, panelId: panelId) {
                session.services.sidebarGitMetadataService.scheduleInitialWorkspaceGitMetadataRefreshIfPossible(
                    workspaceId: workspaceId,
                    panelId: panelId,
                    reason: reason
                )
            }
        }
        session.services.pullRequestProbing.refreshTrackedWorkspacePullRequestsIfNeeded(reason: reason)
    }

    private func stop(_ session: HostSession) {
        session.services.sidebarGitMetadataService.stopSidebarGitMetadataObservation()
        session.services.pullRequestProbing.stopWorkspacePullRequestObservation()
        session.workspaceIds.removeAll()
    }

    private func cancelSubmittedPullRequestMentionRefreshes(workspaceIds: Set<UUID>? = nil) {
        for (key, work) in promptMentionRefreshTasksByKey {
            guard workspaceIds?.contains(key.workspaceId) ?? true else { continue }
            work.task.cancel()
            promptMentionRefreshTasksByKey.removeValue(forKey: key)
        }
    }

    private static func promptMentionOwnerURL(explicitURLString: String?, ownerLogin: String?) -> URL? {
        if let explicitURLString, let explicitURL = URL(string: explicitURLString) {
            return explicitURL
        }
        guard let ownerLogin = ownerLogin?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ownerLogin.isEmpty else { return nil }
        return URL(string: "https://github.com/\(ownerLogin)")
    }

    private func updateLifecycleState(from result: SidebarGitPullRequestObservationRuntimeOperationResult) {
        switch result {
        case .ready:
            lifecycleState = .ready
        case .disabled(let reason):
            lifecycleState = .disabled(reason: reason)
        case .degraded(let reason):
            lifecycleState = .degraded(reason: reason)
        case .failed(let reason):
            lifecycleState = .failed(reason: reason)
        }
    }
}
