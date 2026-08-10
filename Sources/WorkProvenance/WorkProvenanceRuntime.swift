import AppKit
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

/// Main-actor runtime that wires workspace lifecycle to observe-only provenance storage.
@MainActor
final class WorkProvenanceRuntime {
    private weak var tabManager: TabManager?
    private let observationService: WorkProvenanceObservationService?
    private let workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore?
    private let sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder?
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
        sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder? = nil,
        effectiveDatabaseURL: URL? = nil,
        startupErrorDescription: String? = nil
    ) {
        self.observationService = observationService
        self.workspaceDisplayCurrentStateStore = workspaceDisplayCurrentStateStore
        self.sessionLifecycleRecorder = sessionLifecycleRecorder
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
        homeDirectory: URL = WorkProvenanceStorageLocation.defaultHomeDirectory()
    ) -> WorkProvenanceRuntime {
        let location = WorkProvenanceStorageLocation(homeDirectory: homeDirectory)
        do {
            let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
                try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
            NSLog("bmux provenance runtime using database: %@", location.databaseURL.path)
            return WorkProvenanceRuntime(
                observationService: WorkProvenanceObservationService(
                    client: client,
                    gitInspector: WorkProvenanceGitInspector()
                ),
                workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore(client: client),
                sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder(
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

    private func handleCurrentDirectoryNotification(_ notification: Notification) {
        observeWorkspace(from: notification)
    }

    private func observeWorkspace(from notification: Notification) {
        let workspaceID = (notification.userInfo?["workspaceId"] as? UUID)
            ?? (notification.userInfo?[GhosttyNotificationKey.tabId] as? UUID)
        guard let workspaceID,
              let workspace = tabManager?.tabs.first(where: { $0.id == workspaceID }) else {
            return
        }
        observeWorkspaces([workspace])
    }

    private func refreshAllWorkspaceDisplayCurrentState() {
        refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: tabManager?.tabs.map(\.stableId) ?? [])
    }

    private func refreshWorkspaceDisplayCurrentState(stableWorkspaceIDs: [UUID]) {
        workspaceDisplayCurrentStateStore?.refresh(
            stableWorkspaceIDs: stableWorkspaceIDs,
            notify: { [weak self] stableWorkspaceID in
                self?.workspaceDisplayCurrentStateDidChange(stableWorkspaceID: stableWorkspaceID)
            }
        )
    }

    private func workspaceDisplayCurrentStateDidChange(stableWorkspaceID: UUID) {
        guard let tabManager,
              let workspace = tabManager.tabs.first(where: { $0.stableId == stableWorkspaceID }) else {
            return
        }
        tabManager.objectWillChange.send()
        workspace.sidebarImmediateObservationChangeSubject.send(())
    }

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
