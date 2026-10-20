import Foundation
import Observation
import ProvenanceEngineContracts

/// Session-scoped Explorer navigation and arrangements, independent of live selection.
@MainActor @Observable
final class WorkspaceExplorerCoordinator {
    typealias Loader = @MainActor () async throws -> WorkspaceExplorerHistoryLoadResult
    typealias Reopener = @MainActor (UUID) -> Bool
    typealias Activator = @MainActor (UUID) -> Void
    typealias SessionLoader = @MainActor (UUID) async throws -> ProvenanceWorkspaceSessionPageResponse
    typealias Clearer = @MainActor () async throws -> Void

    var scope = WorkspaceExplorerScope()
    var overviewArrangement = WorkspaceExplorerViewArrangement()
    private(set) var collectionTarget: WorkspaceExplorerCollectionTarget?
    private(set) var historyID: String?
    private(set) var catalog: WorkspaceExplorerCatalog?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var sessionsByWorkspaceID: [String: ProvenanceWorkspaceSessionPageResponse] = [:]
    private(set) var sessionLoadFailed = false
    private(set) var clearFailed = false
    private var collectionArrangements: [String: WorkspaceExplorerViewArrangement] = [:]

    private let loadHistory: Loader
    private let reopenHistory: Reopener
    private let activateWorkspace: Activator
    private let loadSessions: SessionLoader
    private let clearArchive: Clearer

    init(loadHistory: @escaping Loader, reopenHistory: @escaping Reopener,
         activateWorkspace: @escaping Activator, loadSessions: @escaping SessionLoader,
         clearArchive: @escaping Clearer) {
        self.loadHistory = loadHistory
        self.reopenHistory = reopenHistory
        self.activateWorkspace = activateWorkspace
        self.loadSessions = loadSessions
        self.clearArchive = clearArchive
    }

    var activeArrangement: WorkspaceExplorerViewArrangement {
        guard let collectionTarget else { return overviewArrangement }
        return collectionArrangements[key(for: collectionTarget)] ?? WorkspaceExplorerViewArrangement()
    }

    var projection: WorkspaceExplorerProjection? { catalog?.projection }

    func result(now: Date = .now, calendar: Calendar = .current) -> WorkspaceExplorerProjectionResult? {
        guard let projection else { return nil }
        let arrangement = activeArrangement
        if let collectionTarget {
            return projection.collection(target: collectionTarget, scope: scope,
                groupBy: arrangement.groupBy, filters: arrangement.filters,
                now: now, calendar: calendar)
        }
        return projection.overview(scope: scope, groupBy: arrangement.groupBy,
            filters: arrangement.filters, now: now, calendar: calendar)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            catalog = WorkspaceExplorerCatalog(try await loadHistory())
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    func showCollection(_ target: WorkspaceExplorerCollectionTarget) {
        collectionTarget = target
        historyID = nil
    }

    func showHistory(_ id: String) { historyID = id }

    func backFromHistory() { historyID = nil }

    func loadHistorySessions(for id: String) async {
        guard let stableID = UUID(uuidString: id) else { return }
        do {
            sessionsByWorkspaceID[id] = try await loadSessions(stableID)
            sessionLoadFailed = false
        } catch is CancellationError {
            return
        } catch {
            sessionLoadFailed = true
        }
    }

    func showOverview() {
        if case .project(let id) = collectionTarget { overviewArrangement.focusedProjectID = id }
        collectionTarget = nil
        historyID = nil
    }

    func setGroupBy(_ dimensions: [WorkspaceExplorerDimension]) {
        updateArrangement { $0.setGroupBy(dimensions) }
    }

    func setFilter(_ dimension: WorkspaceExplorerDimension, value: WorkspaceExplorerGroupKey?) {
        updateArrangement { $0.setFilter(dimension, value: value) }
    }

    func clearFilters() { updateArrangement { $0.clearFilters() } }
    func undo() { updateArrangement { $0.undo() } }
    func toggleCollapsed(_ path: String) { updateArrangement { $0.toggleCollapsed(path) } }

    func open(_ item: WorkspaceExplorerHistoryItem) {
        if let liveID = item.liveWorkspaceID {
            activateWorkspace(liveID)
        } else {
            showHistory(item.id)
        }
    }

    func reopen(_ item: WorkspaceExplorerHistoryItem) async -> Bool {
        guard case .eligible = item.reopenEligibility,
              let id = UUID(uuidString: item.id), reopenHistory(id) else { return false }
        await load()
        return true
    }

    func clearHistory() async {
        do {
            try await clearArchive()
            clearFailed = false
            sessionsByWorkspaceID.removeAll()
            await load()
        } catch {
            clearFailed = true
        }
    }

    private func updateArrangement(_ change: (inout WorkspaceExplorerViewArrangement) -> Void) {
        guard let collectionTarget else {
            change(&overviewArrangement)
            return
        }
        let key = key(for: collectionTarget)
        var arrangement = collectionArrangements[key] ?? WorkspaceExplorerViewArrangement()
        change(&arrangement)
        collectionArrangements[key] = arrangement
    }

    private func key(for target: WorkspaceExplorerCollectionTarget) -> String {
        switch target {
        case .all: "all"
        case .unassigned: "unassigned"
        case .project(let id): "project:\(id)"
        }
    }
}
