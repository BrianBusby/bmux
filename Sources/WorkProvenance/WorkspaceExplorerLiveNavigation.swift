import AppKit
import Observation

/// Keeps the return route for a live workspace opened from the separate Explorer window.
@MainActor @Observable
final class WorkspaceExplorerLiveNavigation {
    struct Origin: Equatable {
        let workspaceID: UUID
        let collectionTitle: String
    }

    private(set) var origin: Origin?
    @ObservationIgnored private weak var explorerWindow: NSWindow?
    @ObservationIgnored private var closeObserver: NSObjectProtocol?

    func register(window: NSWindow) {
        guard explorerWindow !== window else { return }
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        explorerWindow = window
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.unregister() }
        }
    }

    func unregister() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        explorerWindow = nil
        origin = nil
    }

    func opened(workspaceID: UUID, from collectionTitle: String) {
        origin = Origin(workspaceID: workspaceID, collectionTitle: collectionTitle)
    }

    func origin(for selectedWorkspaceID: UUID?) -> Origin? {
        guard explorerWindow?.isVisible == true,
              origin?.workspaceID == selectedWorkspaceID else { return nil }
        return origin
    }

    func returnToExplorer() {
        guard let explorerWindow else { return }
        explorerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
