import AppKit
import Observation

/// Keeps the return route for a live workspace opened from the separate Explorer window.
@MainActor @Observable
final class WorkspaceExplorerLiveNavigation {
    struct Origin: Equatable {
        let workspaceID: UUID
        let stableID: UUID
        let collectionTarget: WorkspaceExplorerCollectionTarget?
        let collectionTitle: String
    }

    private(set) var origin: Origin?
    private(set) var retainedSessionCount: Int?
    @ObservationIgnored private weak var explorerWindow: NSWindow?
    @ObservationIgnored private weak var coordinator: WorkspaceExplorerCoordinator?
    @ObservationIgnored private var closeObserver: NSObjectProtocol?
    @ObservationIgnored private var countTask: Task<Void, Never>?
    @ObservationIgnored private let raise: @MainActor (NSWindow) -> Void

    init(raise: @escaping @MainActor (NSWindow) -> Void = { window in
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }) {
        self.raise = raise
    }

    func register(window: NSWindow, coordinator: WorkspaceExplorerCoordinator) {
        self.coordinator = coordinator
        guard explorerWindow !== window else { return }
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        explorerWindow = window
#if DEBUG
        bmuxDebugLog("explorer.live.register windowVisible=\(window.isVisible)")
#endif
        let windowID = ObjectIdentifier(window)
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.explorerWindow.map(ObjectIdentifier.init) == windowID else { return }
                self.unregister()
            }
        }
    }

    func unregister() {
#if DEBUG
        bmuxDebugLog("explorer.live.unregister")
#endif
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        countTask?.cancel()
        countTask = nil
        explorerWindow = nil
        coordinator = nil
        origin = nil
        retainedSessionCount = nil
    }

    func opened(item: WorkspaceExplorerHistoryItem, target: WorkspaceExplorerCollectionTarget?,
                from collectionTitle: String,
                loadSessions: @escaping WorkspaceExplorerCoordinator.SessionLoader) {
        guard let workspaceID = item.liveWorkspaceID,
              let stableID = UUID(uuidString: item.id) else { return }
        let opened = Origin(workspaceID: workspaceID, stableID: stableID,
            collectionTarget: target, collectionTitle: collectionTitle)
        countTask?.cancel()
        origin = opened
        retainedSessionCount = nil
#if DEBUG
        bmuxDebugLog("explorer.live.opened hasWindow=\(explorerWindow != nil) windowVisible=\(explorerWindow?.isVisible == true)")
#endif
        countTask = Task { [weak self] in
            do {
                let page = try await loadSessions(stableID)
                guard !Task.isCancelled, self?.origin == opened else { return }
                self?.retainedSessionCount = page.totalCount
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self?.origin == opened else { return }
                self?.retainedSessionCount = nil
            }
        }
    }

    func origin(for selectedWorkspaceID: UUID?) -> Origin? {
        guard let origin, origin.workspaceID == selectedWorkspaceID,
              explorerWindow != nil else { return nil }
        return origin
    }

    func returnToOverview() {
        guard let coordinator else { return }
        coordinator.showOverview()
        raiseExplorer()
    }

    func returnToCollection() {
        guard let coordinator, let origin else { return }
        if let target = origin.collectionTarget {
            coordinator.showCollection(target)
        } else {
            coordinator.showOverview()
        }
        raiseExplorer()
    }

    func openHistory() {
        guard let coordinator, let origin, (retainedSessionCount ?? 0) > 0 else { return }
        coordinator.showCollection(origin.collectionTarget ?? .all)
        coordinator.showHistory(origin.stableID.uuidString)
        raiseExplorer()
    }

    private func raiseExplorer() {
        guard let explorerWindow else { return }
        raise(explorerWindow)
    }
}
