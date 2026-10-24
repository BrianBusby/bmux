import Foundation
import Observation

/// Invalidates an open Explorer when live workspace identities change.
@MainActor
final class WorkspaceExplorerWorkspaceChangeMonitor {
    typealias TabManagers = @MainActor () -> [TabManager]

    private let tabManagers: TabManagers
    private var contextTask: Task<Void, Never>?
    private var managerIDs: [ObjectIdentifier: Set<UUID>] = [:]
    private var onChange: (@MainActor () -> Void)?
    private var hasBoundManagers = false
    private var bindingGeneration = 0

    init(tabManagers: @escaping TabManagers) { self.tabManagers = tabManagers }

    func start(onChange: @escaping @MainActor () -> Void) {
        stop()
        self.onChange = onChange
        bindManagers()
        contextTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .mainWindowContextsDidChange) {
                guard !Task.isCancelled else { break }
                self?.windowContextsChanged()
            }
        }
    }

    func stop() {
        contextTask?.cancel()
        contextTask = nil
        managerIDs.removeAll()
        onChange = nil
        hasBoundManagers = false
        bindingGeneration &+= 1
    }

    func windowContextsChanged() { bindManagers() }

    private func bindManagers() {
        let previous = Set(managerIDs.values.flatMap { $0 })
        managerIDs.removeAll()
        bindingGeneration &+= 1
        let generation = bindingGeneration
        var seen: Set<ObjectIdentifier> = []
        for manager in tabManagers() where seen.insert(ObjectIdentifier(manager)).inserted {
            let key = ObjectIdentifier(manager)
            managerIDs[key] = Set(manager.workspaces.tabs.map(\.stableId))
            observe(manager: manager, generation: generation)
        }
        if hasBoundManagers && previous != Set(managerIDs.values.flatMap { $0 }) {
            onChange?()
        }
        hasBoundManagers = true
    }

    private func observe(manager: TabManager, generation: Int) {
        let ids = withObservationTracking {
            Set(manager.workspaces.tabs.map(\.stableId))
        } onChange: { [weak self, weak manager] in
            // Observation fires in willSet; re-arm after the new tab list is stored.
            Task { @MainActor [weak self, weak manager] in
                guard let self, let manager, generation == self.bindingGeneration else { return }
                self.observe(manager: manager, generation: generation)
            }
        }
        update(manager: ObjectIdentifier(manager), ids: ids, generation: generation)
    }

    private func update(manager: ObjectIdentifier, ids: Set<UUID>, generation: Int) {
        guard generation == bindingGeneration, managerIDs[manager] != ids else { return }
        managerIDs[manager] = ids
        onChange?()
    }
}
