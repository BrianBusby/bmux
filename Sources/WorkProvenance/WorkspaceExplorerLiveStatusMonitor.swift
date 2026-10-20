import Combine
import Foundation

/// Watches bmux-owned lifecycle and connection signals while an Explorer window is open.
@MainActor
final class WorkspaceExplorerLiveStatusMonitor {
    typealias WorkspaceSource = @MainActor () -> [Workspace]

    private let workspaces: WorkspaceSource
    private var subscriptions: [AnyCancellable] = []

    init(workspaces: @escaping WorkspaceSource) {
        self.workspaces = workspaces
    }

    func start(onChange: @escaping @MainActor (String, WorkspaceExplorerStatus) -> Void) {
        subscriptions.removeAll()
        for workspace in workspaces() {
            let workspaceID = workspace.stableId.uuidString
            let lifecycle = workspace.agentLifecycleStatesByPanelIdPublisher.map { _ in () }
            let processes = workspace.agentPIDKeysByPanelIdPublisher.map { _ in () }
            let connection = workspace.$remoteConnectionState.map { _ in () }
            subscriptions.append(Publishers.Merge3(lifecycle, processes, connection).sink { [weak workspace] _ in
                // Workspace publishers are mutated on the main actor; fail loudly if that contract changes.
                MainActor.assumeIsolated {
                    guard let workspace else { return }
                    onChange(workspaceID, WorkspaceExplorerLiveWorkspace.verifiedStatus(of: workspace))
                }
            })
        }
    }
}
