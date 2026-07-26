import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

/// Main-actor runtime that wires workspace lifecycle to observe-only provenance storage.
@MainActor
final class WorkProvenanceRuntime {
    private weak var tabManager: TabManager?
    private let observationService: WorkProvenanceObservationService?
    private let sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder?
    private var directoryObservationTask: Task<Void, Never>?

    /// Whether the runtime has a usable provenance store.
    let isEnabled: Bool

    /// Creates a provenance runtime.
    init(
        observationService: WorkProvenanceObservationService?,
        sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder? = nil
    ) {
        self.observationService = observationService
        self.sessionLifecycleRecorder = sessionLifecycleRecorder
        self.isEnabled = observationService != nil
    }

    deinit {
        directoryObservationTask?.cancel()
    }

    /// Creates the standard runtime backed by the per-user bmux state directory.
    static func live(fileManager: FileManager = .default) -> WorkProvenanceRuntime {
        let location = WorkProvenanceStorageLocation(homeDirectory: fileManager.homeDirectoryForCurrentUser)
        do {
            let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
                try ProvenanceEngineClientFactory().sqliteClient(databaseURL: location.databaseURL)
            return WorkProvenanceRuntime(
                observationService: WorkProvenanceObservationService(
                    client: client,
                    gitInspector: WorkProvenanceGitInspector()
                ),
                sessionLifecycleRecorder: WorkProvenanceSessionLifecycleRecorder(
                    client: client
                )
            )
        } catch {
            return WorkProvenanceRuntime(observationService: nil)
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
    }

    /// Observes the provided live workspaces.
    func observeWorkspaces(_ workspaces: [Workspace]) {
        guard let observationService else { return }
        let snapshots = workspaces.map(WorkProvenanceWorkspaceSnapshot.init(workspace:))
        Task {
            await observationService.observeWorkspaceSnapshots(snapshots)
        }
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

    private func handleCurrentDirectoryNotification(_ notification: Notification) {
        guard let workspaceID = notification.userInfo?["workspaceId"] as? UUID,
              let workspace = tabManager?.tabs.first(where: { $0.id == workspaceID }) else {
            return
        }
        observeWorkspaces([workspace])
    }
}
