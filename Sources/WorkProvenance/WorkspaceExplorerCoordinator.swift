import Foundation
import Observation
import ProvenanceEngineContracts

/// Session-scoped Explorer navigation and arrangements, independent of live selection.
@MainActor @Observable
final class WorkspaceExplorerCoordinator {
    typealias Loader = @MainActor () async throws -> WorkspaceExplorerHistoryLoadResult
    typealias PresenceLoader = @MainActor () -> WorkspaceExplorerHistoryLoadResult
    typealias Reopener = @MainActor (UUID) -> Bool
    typealias Activator = @MainActor (UUID) -> Void
    typealias SessionLoader = @MainActor (UUID) async throws -> ProvenanceWorkspaceSessionPageResponse
    typealias MoreSessionsLoader = @MainActor (UUID, String) async throws -> ProvenanceWorkspaceSessionPageResponse
    typealias EvidenceLoader = @MainActor (String) async throws -> (
        ProvenanceFactualSessionProjectionResponse, ProvenanceSessionOutcomeResponse
    )
    typealias Clearer = @MainActor () async throws -> Void
    typealias FeedbackDelay = @MainActor (Duration) async throws -> Void

    var scope = WorkspaceExplorerScope()
    var overviewArrangement = WorkspaceExplorerViewArrangement()
    private(set) var collectionTarget: WorkspaceExplorerCollectionTarget?
    private(set) var historyID: String?
    private(set) var catalog: WorkspaceExplorerCatalog?
    private(set) var activeWorkspaceID: String?
    private var lastLoadResult: WorkspaceExplorerHistoryLoadResult?
    private var loadGeneration = 0
    private var observedStatusIDs: Set<String> = []
    private var statusArrangement = WorkspaceExplorerStatusArrangement()
    private var liveStatusOverrides: [String: WorkspaceExplorerStatus] = [:]
    private let liveStatusMonitor: WorkspaceExplorerLiveStatusMonitor?
    var pendingStatusChangeCount: Int { statusArrangement.pendingWorkspaceIDs.count }
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var sessionsByWorkspaceID: [String: ProvenanceWorkspaceSessionPageResponse] = [:]
    private(set) var sessionLoadFailed = false
    private(set) var evidenceBySessionID: [String: SessionEvidence] = [:]
    private var evidenceOrder: [String] = []
    private(set) var evidenceLoadingIDs: Set<String> = []
    private(set) var evidenceFailedIDs: Set<String> = []
    private(set) var clearFailed = false
    private(set) var reopenedTitle: String?
    private(set) var reopenedWorkspaceID: String?
    private(set) var reopenFailed = false
    private var feedbackTask: Task<Void, Never>?
    private var focusTask: Task<Void, Never>?
    private var collectionArrangements: [String: WorkspaceExplorerViewArrangement] = [:]

    private let loadHistory: Loader
    private let loadPresence: PresenceLoader?
    private let reopenHistory: Reopener
    private let activateWorkspace: Activator
    private let loadSessions: SessionLoader
    private let loadMoreSessions: MoreSessionsLoader
    private let loadEvidence: EvidenceLoader
    private let clearArchive: Clearer
    private let feedbackDelay: FeedbackDelay

    init(loadHistory: @escaping Loader, loadPresence: PresenceLoader? = nil,
         reopenHistory: @escaping Reopener,
         activateWorkspace: @escaping Activator, loadSessions: @escaping SessionLoader,
         loadEvidence: @escaping EvidenceLoader = { _ in throw CancellationError() },
         loadMoreSessions: @escaping MoreSessionsLoader = { _, _ in throw CancellationError() },
         clearArchive: @escaping Clearer,
         liveStatusMonitor: WorkspaceExplorerLiveStatusMonitor? = nil,
         feedbackDelay: @escaping FeedbackDelay = { try await Task.sleep(for: $0) }) {
        self.loadHistory = loadHistory
        self.loadPresence = loadPresence
        self.reopenHistory = reopenHistory
        self.activateWorkspace = activateWorkspace
        self.loadSessions = loadSessions
        self.loadMoreSessions = loadMoreSessions
        self.loadEvidence = loadEvidence
        self.clearArchive = clearArchive
        self.feedbackDelay = feedbackDelay
        self.liveStatusMonitor = liveStatusMonitor
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
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }
        observedStatusIDs.removeAll()
        if let loadPresence, catalog?.archiveAvailability != .available {
            present(loadPresence())
            loadFailed = false
        }
        do {
            let result = try await loadHistory()
            guard generation == loadGeneration else { return }
            present(result, preserveObservedStatuses: true)
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            if let lastLoadResult, lastLoadResult.archiveAvailability == .pending {
                present(WorkspaceExplorerHistoryLoadResult(items: lastLoadResult.items,
                    archiveAvailability: .unavailable,
                    partialLiveActivity: lastLoadResult.partialLiveActivity,
                    liveMetadataPending: lastLoadResult.liveMetadataPending,
                    activeWorkspaceID: lastLoadResult.activeWorkspaceID),
                    preserveObservedStatuses: true)
            }
            loadFailed = true
        }
    }

    private func present(_ result: WorkspaceExplorerHistoryLoadResult,
                         preserveObservedStatuses: Bool = false) {
        let previousStatuses = liveStatusOverrides
        lastLoadResult = result
        activeWorkspaceID = result.activeWorkspaceID
        liveStatusOverrides = Dictionary(uniqueKeysWithValues: result.items.filter(\.isOpen)
            .map { item in
                (item.id, preserveObservedStatuses && observedStatusIDs.contains(item.id) ?
                    previousStatuses[item.id] ?? item.liveStatus : item.liveStatus)
            })
        let arrangement = activeArrangement
        let currentIDs = Set(result.items.map(\.id))
        for oldID in statusArrangement.pendingWorkspaceIDs where !currentIDs.contains(oldID) {
            statusArrangement.remove(workspaceID: oldID)
        }
        for item in result.items where !item.isOpen {
            statusArrangement.remove(workspaceID: item.id)
        }
        for item in result.items where item.isOpen {
            statusArrangement.observe(workspaceID: item.id,
                status: liveStatusOverrides[item.id] ?? item.liveStatus,
                groupBy: arrangement.groupBy, filters: arrangement.filters)
        }
        catalog = WorkspaceExplorerCatalog(result, liveStatuses: liveStatusOverrides,
            arrangedStatuses: arrangedStatuses())
        liveStatusMonitor?.start { [weak self] id, status in
            self?.observeLiveStatus(id: id, status: status)
        }
    }

    func loadMoreHistorySessions(for id: String) async {
        guard let stableID = UUID(uuidString: id),
              let current = sessionsByWorkspaceID[id], let cursor = current.nextCursor else { return }
        do {
            let next = try await loadMoreSessions(stableID, cursor)
            let known = Set(current.sessions.map(\.id))
            sessionsByWorkspaceID[id] = ProvenanceWorkspaceSessionPageResponse(
                workspaceID: current.workspaceID,
                sessions: current.sessions + next.sessions.filter { !known.contains($0.id) },
                nextCursor: next.nextCursor,
                partialCoverage: current.partialCoverage || next.partialCoverage)
            sessionLoadFailed = false
        } catch is CancellationError {
            return
        } catch {
            sessionLoadFailed = true
        }
    }

    func observeLiveStatus(id: String, status: WorkspaceExplorerStatus) {
        guard let lastLoadResult, lastLoadResult.items.contains(where: { $0.id == id && $0.isOpen }) else { return }
        guard statusArrangement.liveStatus(for: id) != status else { return }
        observedStatusIDs.insert(id)
        liveStatusOverrides[id] = status
        let arrangement = activeArrangement
        statusArrangement.observe(workspaceID: id, status: status,
            groupBy: arrangement.groupBy, filters: arrangement.filters)
        catalog = WorkspaceExplorerCatalog(lastLoadResult, liveStatuses: liveStatusOverrides,
            arrangedStatuses: arrangedStatuses())
    }

    func applyPendingStatusArrangement() {
        statusArrangement.applyPending()
        if let lastLoadResult {
            catalog = WorkspaceExplorerCatalog(lastLoadResult, liveStatuses: liveStatusOverrides,
                arrangedStatuses: arrangedStatuses())
        }
    }

    func stopLiveStatusMonitoring() { liveStatusMonitor?.stop() }

    private func arrangedStatuses() -> [String: WorkspaceExplorerStatus] {
        guard let lastLoadResult else { return [:] }
        return Dictionary(uniqueKeysWithValues: lastLoadResult.items.compactMap { item in
            statusArrangement.arrangedStatus(for: item.id).map { (item.id, $0) }
        })
    }

    func showCollection(_ target: WorkspaceExplorerCollectionTarget) {
        focusTask?.cancel()
        overviewArrangement.focusedProjectID = nil
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

    func loadSessionEvidence(for id: String) async {
        guard evidenceBySessionID[id] == nil, evidenceLoadingIDs.insert(id).inserted else { return }
        defer { evidenceLoadingIDs.remove(id) }
        do {
            let (projection, outcome) = try await loadEvidence(id)
            evidenceBySessionID[id] = SessionEvidence(projection: projection, outcome: outcome)
            evidenceOrder.append(id)
            if evidenceOrder.count > 10 {
                evidenceBySessionID.removeValue(forKey: evidenceOrder.removeFirst())
            }
            evidenceFailedIDs.remove(id)
        } catch is CancellationError {
            return
        } catch {
            evidenceFailedIDs.insert(id)
        }
    }

    func showOverview() {
        focusTask?.cancel()
        if case .project(let id) = collectionTarget {
            overviewArrangement.focusedProjectID = id
            // Bounded, cancellable orientation cue after returning from a project.
            focusTask = Task { [feedbackDelay] in
                do { try await feedbackDelay(.seconds(1.6)) } catch { return }
                guard !Task.isCancelled else { return }
                overviewArrangement.focusedProjectID = nil
            }
        }
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
    func setScrollAnchor(_ id: String?) {
        guard let id else { return }
        updateArrangement { $0.scrollAnchorID = id }
    }

    func open(_ item: WorkspaceExplorerHistoryItem) {
        if let liveID = item.liveWorkspaceID {
            activateWorkspace(liveID)
            activeWorkspaceID = item.id
        } else {
            showHistory(item.id)
        }
    }

    func reopen(_ item: WorkspaceExplorerHistoryItem) async -> Bool {
        guard case .eligible = item.reopenEligibility,
              let id = UUID(uuidString: item.id) else { return false }
        guard reopenHistory(id) else {
            reopenFailed = true
            return false
        }
        reopenFailed = false
        reopenedTitle = item.title
        reopenedWorkspaceID = item.id
        let holdsClosedCard = scope.state == .closed
        if !holdsClosedCard { await load() }
        feedbackTask?.cancel()
        // Bounded, cancellable confirmation lets a reopened card exit the Closed scope visibly.
        feedbackTask = Task { [feedbackDelay] in
            do { try await feedbackDelay(.seconds(1.1)) } catch { return }
            guard !Task.isCancelled else { return }
            if holdsClosedCard { await load() }
            reopenedTitle = nil
            reopenedWorkspaceID = nil
        }
        return true
    }

    func clearHistory() async {
        do {
            try await clearArchive()
            clearFailed = false
            sessionsByWorkspaceID.removeAll()
            evidenceBySessionID.removeAll()
            evidenceOrder.removeAll()
            historyID = nil
            await load()
        } catch {
            clearFailed = true
        }
    }

    struct SessionEvidence {
        let projection: ProvenanceFactualSessionProjectionResponse
        let outcome: ProvenanceSessionOutcomeResponse
    }

    private func updateArrangement(_ change: (inout WorkspaceExplorerViewArrangement) -> Void) {
        guard let collectionTarget else {
            let previousGroupBy = overviewArrangement.groupBy
            let previousFilters = overviewArrangement.filters
            change(&overviewArrangement)
            reconcileStatusArrangement(previousGroupBy: previousGroupBy, previousFilters: previousFilters)
            return
        }
        let key = key(for: collectionTarget)
        var arrangement = collectionArrangements[key] ?? WorkspaceExplorerViewArrangement()
        let previousGroupBy = arrangement.groupBy
        let previousFilters = arrangement.filters
        change(&arrangement)
        collectionArrangements[key] = arrangement
        reconcileStatusArrangement(previousGroupBy: previousGroupBy, previousFilters: previousFilters)
    }

    private func reconcileStatusArrangement(
        previousGroupBy: [WorkspaceExplorerDimension],
        previousFilters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    ) {
        let current = activeArrangement
        guard previousGroupBy != current.groupBy || previousFilters != current.filters else { return }
        statusArrangement.reconcile(groupBy: current.groupBy, filters: current.filters)
        if let lastLoadResult {
            catalog = WorkspaceExplorerCatalog(lastLoadResult, liveStatuses: liveStatusOverrides,
                arrangedStatuses: arrangedStatuses())
        }
    }

    private func key(for target: WorkspaceExplorerCollectionTarget) -> String {
        switch target {
        case .all: "all"
        case .unassigned: "unassigned"
        case .project(let id): "project:\(id)"
        }
    }
}
