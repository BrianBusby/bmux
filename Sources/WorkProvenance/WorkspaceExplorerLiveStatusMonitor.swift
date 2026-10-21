import Combine
import Foundation

/// Watches bmux-owned lifecycle and connection signals while an Explorer window is open.
@MainActor
final class WorkspaceExplorerLiveStatusMonitor {
    typealias WorkspaceSource = @MainActor () -> [Workspace]

    private let workspaces: WorkspaceSource
    private var subscriptions: [AnyCancellable] = []
    private var changeTasks: [Task<Void, Never>] = []

    init(workspaces: @escaping WorkspaceSource) {
        self.workspaces = workspaces
    }

    func start(onChange: @escaping @MainActor (String, WorkspaceExplorerStatus) -> Void) {
        stop()
        for workspace in workspaces() {
            let workspaceID = workspace.stableId.uuidString
            // The runtime owner emits changes for PIDs, process identities, panel ownership, and lifecycle.
            let runtimeChanges = workspace.sidebarAgentRuntimeObservation.changes()
            changeTasks.append(Task { [weak workspace] in
                for await _ in runtimeChanges {
                    guard !Task.isCancelled, let workspace else { break }
                    onChange(workspaceID, WorkspaceExplorerLiveWorkspace.verifiedStatus(of: workspace))
                }
            })
            let lifecycle = workspace.agentLifecycleStatesByPanelIdPublisher.map { _ in () }
            let panelKeys = workspace.agentPIDKeysByPanelIdPublisher.map { _ in () }
            let connection = workspace.$remoteConnectionState.map { _ in () }
            subscriptions.append(Publishers.Merge3(lifecycle, panelKeys, connection).sink { [weak workspace] _ in
                // Workspace publishers are mutated on the main actor; fail loudly if that contract changes.
                MainActor.assumeIsolated {
                    guard let workspace else { return }
                    onChange(workspaceID, WorkspaceExplorerLiveWorkspace.verifiedStatus(of: workspace))
                }
            })
        }
    }

    func stop() {
        changeTasks.forEach { $0.cancel() }
        changeTasks.removeAll()
        subscriptions.removeAll()
    }

    deinit {
        changeTasks.forEach { $0.cancel() }
    }
}
