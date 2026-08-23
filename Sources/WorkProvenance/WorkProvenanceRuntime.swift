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
    private let agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore?
    private let agentSessionSmartSessionStore: AgentSessionSmartSessionStore?
    private let workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription?
    private let sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder?
    private let codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder?
    private var directoryObservationTask: Task<Void, Never>?
    private var titleObservationTask: Task<Void, Never>?
    private var displayMetadataObservationTask: Task<Void, Never>?
    private var activationObservationTask: Task<Void, Never>?
    private var executionTelemetryProjectionService: ExecutionTelemetryProvenanceProjectionService?

    /// Effective V1 database path when the runtime starts successfully.
    let effectiveDatabaseURL: URL?

    /// Startup failure retained for diagnostics when provenance is disabled.
    let startupErrorDescription: String?

    /// Whether the runtime has a usable provenance store.
    let isEnabled: Bool

    /// Creates a provenance runtime.
    init(
        observationService: WorkProvenanceObservationService?,
        workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore? = nil,
        agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore? = nil,
        agentSessionSmartSessionStore: AgentSessionSmartSessionStore? = nil,
        workspaceDisplayCurrentStateSubscription: WorkspaceDisplayCurrentStateSubscription? = nil,
        sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder? = nil,
        codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder? = nil,
        effectiveDatabaseURL: URL? = nil,
        startupErrorDescription: String? = nil
    ) {
        self.observationService = observationService
        self.workspaceDisplayCurrentStateStore = workspaceDisplayCurrentStateStore
        self.agentSessionFactualProjectionStore = agentSessionFactualProjectionStore
        self.agentSessionSmartSessionStore = agentSessionSmartSessionStore
        self.workspaceDisplayCurrentStateSubscription = workspaceDisplayCurrentStateSubscription
        self.sessionLifecycleRecorder = sessionLifecycleRecorder
        self.codingAgentEvidenceRecorder = codingAgentEvidenceRecorder
        self.effectiveDatabaseURL = effectiveDatabaseURL
        self.startupErrorDescription = startupErrorDescription
        self.isEnabled = observationService != nil
    }

    deinit {
        directoryObservationTask?.cancel()
        titleObservationTask?.cancel()
        displayMetadataObservationTask?.cancel()
        activationObservationTask?.cancel()
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

    /// Starts observing workspace list and current-directory changes.
    func start(tabManager: TabManager) {
        guard let observationService else { return }
        self.tabManager = tabManager
        Task {
            await observationService.pruneExpiredObservedHistory()
        }
        observeWorkspaces(tabManager.tabs)
        startDirectoryObservationIfNeeded()
        startDisplayObservationIfNeeded()
        startActivationObservationIfNeeded()
        startWorkspaceDisplayCurrentStateSubscriptionIfNeeded()
    }

    /// Starts projecting eligible live execution telemetry facts into provenance.
    func startExecutionTelemetryProjection(
        agentChatURL: URL,
        sidecarStatusHandler: @escaping (ExecutionTelemetryProjectionSidecarStatus) -> Void = { _ in }
    ) {
        guard let sessionLifecycleRecorder else { return }
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
        guard let observationService else { return }
        let snapshots = workspaces.map(WorkProvenanceWorkspaceSnapshot.init(workspace:))
        let stableWorkspaceIDs = snapshots.map(\.stableWorkspaceID)
        Task {
            await observationService.observeWorkspaceSnapshots(snapshots)
            await MainActor.run {
                self.refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: stableWorkspaceIDs)
            }
        }
    }

    /// Reads the latest PE-owned workspace display state cached for a workspace.
    func workspaceDisplayCurrentStateSnapshot(for workspace: Workspace) -> WorkspaceDisplayCurrentStateSnapshot? {
        workspaceDisplayCurrentStateStore?.snapshot(for: workspace)
    }

    /// Reads the PE factual session projection for the latest submitted prompt in one workspace.
    func agentSessionFactualProjection(stableWorkspaceID: UUID) async -> AgentSessionFactualProjectionReadResult {
        guard let workspaceDisplayCurrentStateStore,
              let agentSessionFactualProjectionStore else {
            return .unavailable
        }
        let displaySnapshot = await workspaceDisplayCurrentStateStore.refreshedSnapshot(
            stableWorkspaceID: stableWorkspaceID
        )
        guard let sessionID = displaySnapshot?.lastSubmittedPromptSessionID else {
            return .missingSession
        }
        return await agentSessionFactualProjectionStore.refreshedSnapshot(sessionID: sessionID)
    }

    /// Reads the first-pass React Smart Session bridge snapshot for the latest submitted prompt.
    func agentSessionSmartSession(stableWorkspaceID: UUID) async -> AgentSessionSmartSessionReadResult {
        guard let workspaceDisplayCurrentStateStore,
              let agentSessionSmartSessionStore else {
            return .unavailable
        }
        let displaySnapshot = await workspaceDisplayCurrentStateStore.refreshedSnapshot(
            stableWorkspaceID: stableWorkspaceID
        )
        guard let sessionID = displaySnapshot?.lastSubmittedPromptSessionID else {
            return .missingSession
        }
        return await agentSessionSmartSessionStore.refreshedSnapshot(sessionID: sessionID)
    }

    /// Refreshes one workspace display projection from PE for tab/sidebar rendering.
    func refreshWorkspaceDisplayCurrentState(for workspace: Workspace) {
        refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [workspace.stableId])
    }

    /// Persists an observed agent session lifecycle change.
    func recordSessionLifecycleChange(_ change: AgentSessionLifecycleChange, timestamp: Date) {
        guard let sessionLifecycleRecorder else { return }
        Task {
            await sessionLifecycleRecorder.record(change, timestamp: timestamp)
        }
    }

    /// Persists hook-observed prompt evidence when sidecar telemetry has not linked the workspace yet.
    func recordHookUserPromptSubmit(record: AgentChatSessionRecord, event: WorkstreamEvent) {
        guard let codingAgentEvidenceRecorder,
              let workspace = workspace(forRuntimeOrStableWorkspaceID: record.workspaceID ?? event.workspaceId) else {
            return
        }
        let stableWorkspaceID = workspace.stableId
        let fallbackPromptText = workspace.latestSubmittedMessage
        Task { [weak self] in
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
        }
    }

    /// Persists transcript-observed prompt evidence when sidecar telemetry did not project it.
    func recordTranscriptUserPrompts(record: AgentChatSessionRecord, messages: [ChatMessage]) {
        guard let codingAgentEvidenceRecorder, !messages.isEmpty else { return }
        let stableWorkspaceID = workspace(forRuntimeOrStableWorkspaceID: record.workspaceID)?.stableId
        Task { [weak self] in
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
        }
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

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
