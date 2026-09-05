import AppKit
import BMUXAgentLaunch
import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

/// Main-actor runtime that wires workspace lifecycle to observe-only provenance storage.
@MainActor
final class WorkProvenanceRuntime {
    private weak var tabManager: TabManager?
    private let observationService: WorkProvenanceObservationService?
    private let workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore?
    let workspaceCodingAgentSessionAssociationStore: WorkspaceCodingAgentSessionAssociationStore?
    let agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore?
    let agentSessionSmartSessionStore: AgentSessionSmartSessionStore?
    private let workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription?
    private let sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder?
    private let codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder?
    private var directoryObservationTask: Task<Void, Never>?
    private var titleObservationTask: Task<Void, Never>?
    private var displayMetadataObservationTask: Task<Void, Never>?
    private var activationObservationTask: Task<Void, Never>?
    private var executionTelemetryProjectionService: ExecutionTelemetryProvenanceProjectionService?
    private var backgroundTasksByID: [UUID: Task<Void, Never>] = [:]

    private(set) var lifecycleState: WorkProvenanceRuntimeLifecycleState
    let effectiveDatabaseURL: URL?
    let startupErrorDescription: String?
    let isEnabled: Bool

    var hasActiveLifecycleWork: Bool {
        directoryObservationTask != nil || titleObservationTask != nil ||
            displayMetadataObservationTask != nil || activationObservationTask != nil ||
            executionTelemetryProjectionService != nil || !backgroundTasksByID.isEmpty
    }

    private var acceptsLifecycleProducerWork: Bool { lifecycleState != .stopping && lifecycleState != .stopped }
    private var acceptsObservationProducerWork: Bool { lifecycleState == .starting || lifecycleState == .ready }

    init(
        observationService: WorkProvenanceObservationService?,
        workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore? = nil,
        workspaceCodingAgentSessionAssociationStore: WorkspaceCodingAgentSessionAssociationStore? = nil,
        agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore? = nil,
        agentSessionSmartSessionStore: AgentSessionSmartSessionStore? = nil,
        workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription? = nil,
        sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder? = nil,
        codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder? = nil,
        effectiveDatabaseURL: URL? = nil,
        startupErrorDescription: String? = nil,
        initialLifecycleState: WorkProvenanceRuntimeLifecycleState = .notStarted
    ) {
        self.observationService = observationService
        self.workspaceDisplayCurrentStateStore = workspaceDisplayCurrentStateStore
        self.agentSessionFactualProjectionStore = agentSessionFactualProjectionStore
        self.agentSessionSmartSessionStore = agentSessionSmartSessionStore
        if let workspaceCodingAgentSessionAssociationStore {
            self.workspaceCodingAgentSessionAssociationStore = workspaceCodingAgentSessionAssociationStore
        } else if let agentSessionFactualProjectionStore {
            self.workspaceCodingAgentSessionAssociationStore = WorkspaceCodingAgentSessionAssociationStore(
                client: agentSessionFactualProjectionStore.client
            )
        } else if let agentSessionSmartSessionStore {
            self.workspaceCodingAgentSessionAssociationStore = WorkspaceCodingAgentSessionAssociationStore(
                client: agentSessionSmartSessionStore.client
            )
        } else {
            self.workspaceCodingAgentSessionAssociationStore = nil
        }
        self.workspaceDisplayCurrentStateSubscription = workspaceDisplayCurrentStateSubscription
        self.sessionLifecycleRecorder = sessionLifecycleRecorder
        self.codingAgentEvidenceRecorder = codingAgentEvidenceRecorder
        self.effectiveDatabaseURL = effectiveDatabaseURL
        self.startupErrorDescription = startupErrorDescription
        self.isEnabled = observationService != nil
        self.lifecycleState = initialLifecycleState
    }

    deinit {
        directoryObservationTask?.cancel()
        titleObservationTask?.cancel()
        displayMetadataObservationTask?.cancel()
        activationObservationTask?.cancel()
        backgroundTasksByID.values.forEach { $0.cancel() }
    }

    /// Creates the standard runtime backed by the per-user bmux state directory.
    static func live(
        homeDirectory: URL = WorkProvenanceStorageLocation.defaultHomeDirectory(),
        linearAuthorizationProvider: (any WorkProvenanceLinearAuthorizationProviding)? = nil
    ) -> WorkProvenanceRuntime {
        let location = WorkProvenanceStorageLocation(homeDirectory: homeDirectory)
        do {
            let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
                try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
            let workspaceDisplayCurrentStateStore = WorkspaceDisplayCurrentStateStore(client: client)
            NSLog("bmux provenance runtime using database: %@", location.databaseURL.path)
            return WorkProvenanceRuntime(
                observationService: WorkProvenanceObservationService(
                    client: client,
                    gitInspector: WorkProvenanceGitInspector(),
                    ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                        authorizationProvider: linearAuthorizationProvider
                    )
                ),
                workspaceDisplayCurrentStateStore: workspaceDisplayCurrentStateStore,
                workspaceCodingAgentSessionAssociationStore: WorkspaceCodingAgentSessionAssociationStore(client: client),
                agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore(client: client),
                agentSessionSmartSessionStore: AgentSessionSmartSessionStore(client: client),
                workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription(
                    databaseURL: location.databaseURL
                ),
                sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder(
                    client: client
                ),
                codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder(
                    client: client
                ),
                effectiveDatabaseURL: location.databaseURL
            )
        } catch {
            let description = String(describing: error)
            NSLog("bmux provenance runtime unavailable: %@", description)
            return WorkProvenanceRuntime(
                observationService: nil,
                effectiveDatabaseURL: location.databaseURL,
                startupErrorDescription: description
            )
        }
    }

    static func disabledByComposition() -> WorkProvenanceRuntime {
        WorkProvenanceRuntime(observationService: nil, initialLifecycleState: .stopped)
    }

    /// Starts observing workspace list and current-directory changes.
    @discardableResult
    func start(tabManager: TabManager) -> WorkProvenanceRuntimeLifecycleState {
        switch lifecycleState {
        case .ready, .starting:
            return lifecycleState
        case .stopped where startupErrorDescription == nil && observationService == nil:
            return lifecycleState
        default:
            break
        }
        guard let observationService else {
            if let startupErrorDescription {
                lifecycleState = .failed(reason: startupErrorDescription)
            } else {
                lifecycleState = .degraded(reason: "Work provenance observation is disabled by app runtime composition")
            }
            return lifecycleState
        }
        lifecycleState = .starting
        self.tabManager = tabManager
        trackBackgroundTask(Task {
            await observationService.pruneExpiredObservedHistory()
        })
        observeWorkspaces(tabManager.tabs)
        startDirectoryObservationIfNeeded()
        startDisplayObservationIfNeeded()
        startActivationObservationIfNeeded()
        startWorkspaceDisplayCurrentStateSubscriptionIfNeeded()
        lifecycleState = .ready
        return lifecycleState
    }

    func stop() {
        guard lifecycleState != .stopped else { return }
        lifecycleState = .stopping
        directoryObservationTask?.cancel()
        directoryObservationTask = nil
        titleObservationTask?.cancel()
        titleObservationTask = nil
        displayMetadataObservationTask?.cancel()
        displayMetadataObservationTask = nil
        activationObservationTask?.cancel()
        activationObservationTask = nil
        workspaceDisplayCurrentStateSubscription?.stop()
        workspaceDisplayCurrentStateStore?.cancelRefreshes()
        executionTelemetryProjectionService?.stop()
        executionTelemetryProjectionService = nil
        backgroundTasksByID.values.forEach { $0.cancel() }
        backgroundTasksByID.removeAll()
        tabManager = nil
        lifecycleState = .stopped
    }

    /// Starts projecting eligible live execution telemetry facts into provenance.
    func startExecutionTelemetryProjection(
        agentChatURL: URL,
        sidecarStatusHandler: @escaping (ExecutionTelemetryProjectionSidecarStatus) -> Void = { _ in }
    ) {
        guard acceptsLifecycleProducerWork, let sessionLifecycleRecorder else { return }
        guard executionTelemetryProjectionService?.agentChatURL != agentChatURL else {
            executionTelemetryProjectionService?.updateSidecarStatusHandler(sidecarStatusHandler)
            executionTelemetryProjectionService?.start()
            return
        }
        executionTelemetryProjectionService?.stop()
        let service = ExecutionTelemetryProvenanceProjectionService(
            agentChatURL: agentChatURL,
            lifecycleRecorder: sessionLifecycleRecorder,
            codingAgentEvidenceRecorder: codingAgentEvidenceRecorder,
            sidecarStatusHandler: sidecarStatusHandler
        )
        executionTelemetryProjectionService = service
        service.start()
    }

    /// Observes the provided live workspaces.
    func observeWorkspaces(_ workspaces: [Workspace]) {
        StartupBreadcrumbLog.append("workProvenance.runtime.observeWorkspaces", fields: [
            "count": "\(workspaces.count)"
        ])
        guard acceptsObservationProducerWork else { return }
        guard let observationService else { return }
        let snapshots = workspaces.map(WorkProvenanceWorkspaceSnapshot.init(workspace:))
        let stableWorkspaceIDs = snapshots.map(\.stableWorkspaceID)
        trackBackgroundTask(Task { [weak self] in
            await observationService.observeWorkspaceSnapshots(snapshots)
            await MainActor.run {
                self?.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: stableWorkspaceIDs)
            }
        })
    }

    func waitForBackgroundTasks() async {
        while true {
            let tasksByID = backgroundTasksByID
            guard !tasksByID.isEmpty else { return }
            for task in tasksByID.values {
                await task.value
            }
            for id in tasksByID.keys {
                backgroundTasksByID[id] = nil
            }
        }
    }

    private func trackBackgroundTask(_ task: Task<Void, Never>) {
        let id = UUID()
        backgroundTasksByID[id] = task
        Task { @MainActor [weak self] in
            await task.value
            self?.backgroundTasksByID[id] = nil
        }
    }

    /// Reads the latest PE-owned workspace display state cached for a workspace.
    func workspaceDisplayCurrentStateSnapshot(for workspace: Workspace) -> WorkspaceDisplayCurrentStateSnapshot? {
        workspaceDisplayCurrentStateStore?.snapshot(for: workspace)
    }

    /// Refreshes one workspace display projection from PE for tab/sidebar rendering.
    func refreshWorkspaceDisplayCurrentState(for workspace: Workspace) {
        refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [workspace.stableId])
    }

    /// Persists an observed agent session lifecycle change.
    func recordSessionLifecycleChange(_ change: AgentSessionLifecycleChange, timestamp: Date) {
        guard acceptsLifecycleProducerWork, let sessionLifecycleRecorder else { return }
        trackBackgroundTask(Task {
            await sessionLifecycleRecorder.record(change, timestamp: timestamp)
        })
    }

    /// Persists hook-observed prompt evidence when sidecar telemetry has not linked the workspace yet.
    func recordHookUserPromptSubmit(record: AgentChatSessionRecord, event: WorkstreamEvent) {
        guard acceptsLifecycleProducerWork, let codingAgentEvidenceRecorder,
              let workspace = workspace(forRuntimeOrStableWorkspaceID: record.workspaceID ?? event.workspaceId) else {
            return
        }
        let stableWorkspaceID = workspace.stableId
        let fallbackPromptText = workspace.latestSubmittedMessage
        trackBackgroundTask(Task { [weak self] in
            do {
                try await codingAgentEvidenceRecorder.recordHookUserPromptSubmit(
                    record: record,
                    event: event,
                    stableWorkspaceID: stableWorkspaceID,
                    fallbackPromptText: fallbackPromptText
                )
                await MainActor.run {
                    self?.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [stableWorkspaceID])
                }
            } catch {
                StartupBreadcrumbLog.append("workProvenance.hookPrompt.recordFailed", fields: [
                    "session": record.sessionID,
                    "error": String(describing: error)
                ])
            }
        })
    }

    /// Persists transcript-observed prompt evidence when sidecar telemetry did not project it.
    func recordTranscriptUserPrompts(record: AgentChatSessionRecord, messages: [ChatMessage]) {
        guard acceptsLifecycleProducerWork, let codingAgentEvidenceRecorder, !messages.isEmpty else { return }
        let stableWorkspaceID = workspace(forRuntimeOrStableWorkspaceID: record.workspaceID)?.stableId
        trackBackgroundTask(Task { [weak self] in
            do {
                try await codingAgentEvidenceRecorder.recordTranscriptUserPrompts(
                    record: record,
                    messages: messages,
                    stableWorkspaceID: stableWorkspaceID
                )
                if let stableWorkspaceID {
                    await MainActor.run {
                        self?.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [stableWorkspaceID])
                    }
                }
            } catch {
                StartupBreadcrumbLog.append("workProvenance.transcriptPrompt.recordFailed", fields: [
                    "session": record.sessionID,
                    "error": String(describing: error)
                ])
            }
        })
    }

    private func startDirectoryObservationIfNeeded() {
        guard directoryObservationTask == nil else { return }
        directoryObservationTask = Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .workspaceCurrentDirectoryDidChange
            )
            for await notification in notifications {
                self?.handleCurrentDirectoryNotification(notification)
            }
        }
    }

    private func startDisplayObservationIfNeeded() {
        if titleObservationTask == nil {
            titleObservationTask = Task { @MainActor [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: .workspaceTitleDidChange
                )
                for await notification in notifications {
                    self?.observeWorkspace(from: notification)
                }
            }
        }
        if displayMetadataObservationTask == nil {
            displayMetadataObservationTask = Task { @MainActor [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: .workspaceDisplayMetadataDidChange
                )
                for await notification in notifications {
                    self?.observeWorkspace(from: notification)
                }
            }
        }
    }

    private func startActivationObservationIfNeeded() {
        guard activationObservationTask == nil else { return }
        activationObservationTask = Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: NSApplication.didBecomeActiveNotification
            )
            for await _ in notifications {
                self?.refreshAllWorkspaceDisplayCurrentState()
            }
        }
    }

    private func startWorkspaceDisplayCurrentStateSubscriptionIfNeeded() {
        workspaceDisplayCurrentStateSubscription?.start(
            stableWorkspaceIDs: { [weak self] in
                self?.currentDisplayStableWorkspaceIDs() ?? []
            },
            refresh: { [weak self] stableWorkspaceIDs in
                self?.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: stableWorkspaceIDs)
            }
        )
    }

    private func handleCurrentDirectoryNotification(_ notification: Notification) {
        observeWorkspace(from: notification)
    }

    private func observeWorkspace(from notification: Notification) {
        let workspaceID = (notification.userInfo?["workspaceId"] as? UUID)
            ?? (notification.userInfo?[GhosttyNotificationKey.tabId] as? UUID)
        guard let workspaceID,
              let workspace = Self.workspace(
                matching: workspaceID,
                in: workspaceResolutionTabManagers(for: workspaceID)
              ) else {
            return
        }
        observeWorkspaces([workspace])
    }

    private func refreshAllWorkspaceDisplayCurrentState() {
        refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: currentDisplayStableWorkspaceIDs())
    }

    private func refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [UUID]) {
        guard acceptsObservationProducerWork else { return }
        workspaceDisplayCurrentStateStore?.refresh(
            stableWorkspaceIDs: stableWorkspaceIDs,
            notify: { [weak self] stableWorkspaceID in
                self?.workspaceDisplayCurrentStateDidChange(stableWorkspaceID: stableWorkspaceID)
            }
        )
    }

    private func workspace(forRuntimeOrStableWorkspaceID workspaceID: String?) -> Workspace? {
        guard let workspaceID = workspaceID.flatMap(UUID.init(uuidString:)) else { return nil }
        return Self.workspace(
            matching: workspaceID,
            in: workspaceResolutionTabManagers(for: workspaceID)
        )
    }

    static func workspace(matching workspaceID: UUID, in tabManagers: [TabManager]) -> Workspace? {
        workspaceMatch(matching: workspaceID, in: tabManagers)?.workspace
    }

    static func workspaceMatch(
        matching workspaceID: UUID,
        in tabManagers: [TabManager]
    ) -> (tabManager: TabManager, workspace: Workspace)? {
        var seenManagers: Set<ObjectIdentifier> = []
        for tabManager in tabManagers where seenManagers.insert(ObjectIdentifier(tabManager)).inserted {
            if let workspace = tabManager.tabs.first(where: { workspace in
                workspace.id == workspaceID || workspace.stableId == workspaceID
            }) {
                return (tabManager, workspace)
            }
        }
        return nil
    }

    static func stableWorkspaceIDs(in tabManagers: [TabManager]) -> [UUID] {
        var seenWorkspaceIDs: Set<UUID> = []
        var ids: [UUID] = []
        for tabManager in tabManagers {
            for workspace in tabManager.tabs where seenWorkspaceIDs.insert(workspace.stableId).inserted {
                ids.append(workspace.stableId)
            }
        }
        return ids
    }

    @discardableResult
    static func notifyWorkspaceDisplayCurrentStateDidChange(
        stableWorkspaceID: UUID,
        in tabManagers: [TabManager]
    ) -> Bool {
        guard let match = workspaceMatch(matching: stableWorkspaceID, in: tabManagers) else {
            return false
        }
        match.tabManager.objectWillChange.send()
        match.workspace.sidebarImmediateObservationChangeSubject.send(())
        return true
    }

    private func currentDisplayStableWorkspaceIDs() -> [UUID] {
        Self.stableWorkspaceIDs(in: workspaceResolutionTabManagers(for: nil))
    }

    private func workspaceResolutionTabManagers(for runtimeOrStableWorkspaceID: UUID?) -> [TabManager] {
        var managers: [TabManager] = []
        var seenManagers: Set<ObjectIdentifier> = []
        func append(_ manager: TabManager?) {
            guard let manager,
                  seenManagers.insert(ObjectIdentifier(manager)).inserted else {
                return
            }
            managers.append(manager)
        }

        append(tabManager)
        guard let appDelegate = AppDelegate.shared else { return managers }
        if let runtimeOrStableWorkspaceID {
            append(appDelegate.tabManagerFor(tabId: runtimeOrStableWorkspaceID))
        }
        append(appDelegate.tabManager)
        for window in appDelegate.scriptableMainWindows() {
            append(window.tabManager)
        }
        return managers
    }

    private func workspaceDisplayCurrentStateDidChange(stableWorkspaceID: UUID) {
        Self.notifyWorkspaceDisplayCurrentStateDidChange(
            stableWorkspaceID: stableWorkspaceID,
            in: workspaceResolutionTabManagers(for: stableWorkspaceID)
        )
    }

}
