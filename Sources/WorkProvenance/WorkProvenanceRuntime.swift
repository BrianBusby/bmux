import Foundation

/// Main-actor runtime that wires workspace lifecycle to observe-only provenance storage.
@MainActor
final class WorkProvenanceRuntime {
    private weak var tabManager: TabManager?
    private let observationService: WorkProvenanceObservationService?
    private let subsessionLifecycleRecorder: WorkProvenanceSubsessionLifecycleRecorder?
    private var directoryObservationTask: Task<Void, Never>?

    /// Whether the runtime has a usable provenance store.
    let isEnabled: Bool

    /// Creates a provenance runtime.
    init(
        observationService: WorkProvenanceObservationService?,
        subsessionLifecycleRecorder: WorkProvenanceSubsessionLifecycleRecorder? = nil
    ) {
        self.observationService = observationService
        self.subsessionLifecycleRecorder = subsessionLifecycleRecorder
        self.isEnabled = observationService != nil
    }

    deinit {
        directoryObservationTask?.cancel()
    }

    /// Creates the standard runtime backed by the per-user bmux state directory.
    static func live(fileManager: FileManager = .default) -> WorkProvenanceRuntime {
        let location = WorkProvenanceStorageLocation(homeDirectory: fileManager.homeDirectoryForCurrentUser)
        do {
            let store = try WorkProvenanceStore(databaseURL: location.databaseURL, fileManager: fileManager)
            return WorkProvenanceRuntime(
                observationService: WorkProvenanceObservationService(
                    store: store,
                    gitInspector: WorkProvenanceGitInspector()
                ),
                subsessionLifecycleRecorder: WorkProvenanceSubsessionLifecycleRecorder(store: store)
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

    /// Persists an observed agent subsession lifecycle change.
    func recordSubsessionLifecycleChange(_ change: AgentSubsessionLifecycleChange, timestamp: Date) {
        guard let subsessionLifecycleRecorder else { return }
        Task {
            await subsessionLifecycleRecorder.record(change, timestamp: timestamp)
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
