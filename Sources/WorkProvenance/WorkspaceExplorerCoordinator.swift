import BmuxWorkspaces
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
    typealias LiveOpenHandler = @MainActor (WorkspaceExplorerHistoryItem, WorkspaceExplorerCollectionTarget?, String) -> Void
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
    private let workspaceChangeMonitor: WorkspaceExplorerWorkspaceChangeMonitor?
    private var topologyRefreshTask: Task<Void, Never>?
    private(set) var pendingWorkspaceItems: [WorkspaceExplorerHistoryItem] = []
    var visiblePendingWorkspaceItems: [WorkspaceExplorerHistoryItem] {
        guard historyID == nil, scope.state != .closed, scope.period == .anyTime,
              activeArrangement.filters.isEmpty,
              collectionTarget == nil || collectionTarget == .all else { return [] }
        return pendingWorkspaceItems
    }
    var pendingStatusChangeCount: Int { statusArrangement.pendingWorkspaceIDs.count }
    private(set) var isLoading = false
    private(set) var loadFailed = false
    let sessionPages: WorkspaceExplorerSessionPageStore
    var sessionsByWorkspaceID: [String: ProvenanceWorkspaceSessionPageResponse] {
        sessionPages.pagesByWorkspaceID
    }
    var sessionLoadFailed: Bool {
        historyID.map { sessionPages.failedWorkspaceIDs.contains($0) } ?? false
    }
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
    private let exitTransition: WorkspaceExplorerExitTransition
    private var collectionArrangements: [String: WorkspaceExplorerViewArrangement] = [:]

    private let loadHistory: Loader
    private let loadPresence: PresenceLoader?
    private let reopenHistory: Reopener
    private let activateWorkspace: Activator
    private let onOpenLive: LiveOpenHandler
    private let loadEvidence: EvidenceLoader
    private let clearArchive: Clearer
    private let feedbackDelay: FeedbackDelay

    init(loadHistory: @escaping Loader, loadPresence: PresenceLoader? = nil,
         reopenHistory: @escaping Reopener,
         activateWorkspace: @escaping Activator,
         onOpenLive: @escaping LiveOpenHandler = { _, _, _ in },
         loadSessions: @escaping SessionLoader,
         loadEvidence: @escaping EvidenceLoader = { _ in throw CancellationError() },
         loadMoreSessions: @escaping MoreSessionsLoader = { _, _ in throw CancellationError() },
         clearArchive: @escaping Clearer,
         liveStatusMonitor: WorkspaceExplorerLiveStatusMonitor? = nil,
         workspaceChangeMonitor: WorkspaceExplorerWorkspaceChangeMonitor? = nil,
         feedbackDelay: @escaping FeedbackDelay = { try await Task.sleep(for: $0) }) {
        self.loadHistory = loadHistory
        self.loadPresence = loadPresence
        self.reopenHistory = reopenHistory
        self.activateWorkspace = activateWorkspace
        self.onOpenLive = onOpenLive
        self.sessionPages = WorkspaceExplorerSessionPageStore(loadFirst: loadSessions,
            loadNext: loadMoreSessions)
        self.loadEvidence = loadEvidence
        self.clearArchive = clearArchive
        self.feedbackDelay = feedbackDelay
        self.exitTransition = WorkspaceExplorerExitTransition(delay: feedbackDelay)
        self.liveStatusMonitor = liveStatusMonitor
        self.workspaceChangeMonitor = workspaceChangeMonitor
    }

    var activeArrangement: WorkspaceExplorerViewArrangement {
        guard let collectionTarget else { return overviewArrangement }
        return collectionArrangements[key(for: collectionTarget)] ?? WorkspaceExplorerViewArrangement()
    }

    var presentedScope: WorkspaceExplorerScope { exitTransition.presentation?.scope ?? scope }
    var presentedFilters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey] {
        exitTransition.presentation?.filters ?? activeArrangement.filters
    }
    var exitingProjectIDs: Set<String> { exitTransition.presentation?.exitingProjectIDs ?? [] }
    var exitingWorkspaceIDs: Set<String> { exitTransition.presentation?.exitingWorkspaceIDs ?? [] }
    var exitsUnassigned: Bool { exitTransition.presentation?.exitsUnassigned ?? false }

    var projection: WorkspaceExplorerProjection? { catalog?.projection }
    func result(now: Date = .now, calendar: Calendar = .current) -> WorkspaceExplorerProjectionResult? {
        if let presentation = exitTransition.presentation { return presentation.result }
        return projectedResult(now: now, calendar: calendar)
    }

    private func projectedResult(now: Date = .now, calendar: Calendar = .current) -> WorkspaceExplorerProjectionResult? {
        guard let catalog else { return nil }
        let projection = catalog.projection
        let arrangement = activeArrangement
        if let collectionTarget {
            if catalog.liveMetadataPending {
                guard collectionTarget == .all else { return nil }
                return projection.collection(target: .all, scope: scope,
                    groupBy: [], filters: [:], now: now, calendar: calendar)
            }
            return projection.collection(target: collectionTarget, scope: scope,
                groupBy: arrangement.groupBy, filters: arrangement.filters,
                now: now, calendar: calendar)
        }
        return projection.overview(scope: scope, groupBy: arrangement.groupBy,
            filters: arrangement.filters, now: now, calendar: calendar)
    }

    func load() async {
        exitTransition.cancel()
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }
        observedStatusIDs.removeAll()
        if let loadPresence, catalog == nil || catalog?.liveMetadataPending == true {
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
        let loadedIDs = Set(result.items.map(\.id))
        pendingWorkspaceItems.removeAll { loadedIDs.contains($0.id) || !($0.isOpen) }
        liveStatusMonitor?.start { [weak self] id, status in
            self?.observeLiveStatus(id: id, status: status)
        }
    }

    func loadMoreHistorySessions(for id: String) async {
        await sessionPages.loadNextPage(for: id)
    }

    func observeLiveStatus(id: String, status: WorkspaceExplorerStatus) {
        if let index = pendingWorkspaceItems.firstIndex(where: { $0.id == id }),
           pendingWorkspaceItems[index].liveStatus != status {
            pendingWorkspaceItems[index] = pendingWorkspaceItems[index].withLiveStatus(status)
        }
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

    func startWorkspaceChangeMonitoring() {
        workspaceChangeMonitor?.start { [weak self] in
            guard let self else { return }
            topologyRefreshTask?.cancel()
            // TabManager publishes in willSet; read presence after its mutation returns.
            topologyRefreshTask = Task { [weak self] in await self?.refreshForTopologyChange() }
        }
    }

    func refreshForTopologyChange() async {
        guard let loadPresence else { await load(); return }
        let presence = loadPresence()
        let knownIDs = Set((catalog?.items ?? []).map(\.id))
        pendingWorkspaceItems = presence.items.filter { $0.isOpen && !knownIDs.contains($0.id) }
        activeWorkspaceID = presence.activeWorkspaceID
        liveStatusMonitor?.start { [weak self] id, status in
            self?.observeLiveStatus(id: id, status: status)
        }
        await load()
    }

    func stopLiveStatusMonitoring() {
        exitTransition.cancel()
        topologyRefreshTask?.cancel()
        topologyRefreshTask = nil
        workspaceChangeMonitor?.stop()
        liveStatusMonitor?.stop()
    }
    private func arrangedStatuses() -> [String: WorkspaceExplorerStatus] {
        guard let lastLoadResult else { return [:] }
        return Dictionary(uniqueKeysWithValues: lastLoadResult.items.compactMap { item in
            statusArrangement.arrangedStatus(for: item.id).map { (item.id, $0) }
        })
    }
    func showCollection(_ target: WorkspaceExplorerCollectionTarget) {
        exitTransition.cancel()
        focusTask?.cancel()
        overviewArrangement.focusedProjectID = nil
        collectionTarget = target
        historyID = nil
        sessionPages.activate(nil)
    }

    func showHistory(_ id: String) {
        exitTransition.cancel()
        historyID = id
        sessionPages.activate(id)
    }
    func backFromHistory() {
        historyID = nil
        sessionPages.activate(nil)
    }
    func loadHistorySessions(for id: String) async {
        await sessionPages.loadFirstPage(for: id)
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
        exitTransition.cancel()
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
        sessionPages.activate(nil)
    }

    func setGroupBy(_ dimensions: [WorkspaceExplorerDimension]) {
        updateArrangement { $0.setGroupBy(dimensions) }
    }

    func setFilter(_ dimension: WorkspaceExplorerDimension, value: WorkspaceExplorerGroupKey?, animated: Bool = false) {
        updateArrangement(animated: animated) { $0.setFilter(dimension, value: value) }
    }

    func clearFilters(animated: Bool = false) { updateArrangement(animated: animated) { $0.clearFilters() } }
    func undo(animated: Bool = false) { updateArrangement(animated: animated) { $0.undo() } }
    func setScopeState(_ state: WorkspaceExplorerScope.State, animated: Bool = false) {
        let previous = animated ? result() : nil
        let previousScope = presentedScope
        let previousFilters = presentedFilters
        exitTransition.cancel()
        scope.state = state
        stageExit(from: previous, scope: previousScope, filters: previousFilters, animated: animated)
    }

    func setScopePeriod(_ period: WorkspaceExplorerScope.Period, animated: Bool = false) {
        let previous = animated ? result() : nil
        let previousScope = presentedScope
        let previousFilters = presentedFilters
        exitTransition.cancel()
        scope.period = period
        stageExit(from: previous, scope: previousScope, filters: previousFilters, animated: animated)
    }
    func toggleCollapsed(_ path: String) { updateArrangement { $0.toggleCollapsed(path) } }
    func setScrollAnchor(_ id: String?) {
        guard let id else { return }
        guard let collectionTarget else {
            overviewArrangement.scrollAnchorID = id
            return
        }
        let key = key(for: collectionTarget)
        var arrangement = collectionArrangements[key] ?? WorkspaceExplorerViewArrangement()
        arrangement.scrollAnchorID = id
        collectionArrangements[key] = arrangement
    }

    func open(_ item: WorkspaceExplorerHistoryItem) {
        if let liveID = item.liveWorkspaceID {
            let title = collectionTarget?.title(projects: catalog?.projects ?? [])
                ?? String(localized: "explorer.allProjects", defaultValue: "All projects")
            onOpenLive(item, collectionTarget, title)
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
            sessionPages.clear()
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

    private func updateArrangement(animated: Bool = false,
                                   _ change: (inout WorkspaceExplorerViewArrangement) -> Void) {
        let previous = animated ? result() : nil
        let previousScope = presentedScope
        let presentedFiltersBeforeChange = presentedFilters
        exitTransition.cancel()
        guard let collectionTarget else {
            let previousGroupBy = overviewArrangement.groupBy
            let previousFilters = overviewArrangement.filters
            change(&overviewArrangement)
            reconcileStatusArrangement(previousGroupBy: previousGroupBy, previousFilters: previousFilters)
            if previousGroupBy == overviewArrangement.groupBy {
                stageExit(from: previous, scope: previousScope, filters: presentedFiltersBeforeChange, animated: animated)
            }
            return
        }
        let key = key(for: collectionTarget)
        var arrangement = collectionArrangements[key] ?? WorkspaceExplorerViewArrangement()
        let previousGroupBy = arrangement.groupBy
        let previousFilters = arrangement.filters
        change(&arrangement)
        collectionArrangements[key] = arrangement
        reconcileStatusArrangement(previousGroupBy: previousGroupBy, previousFilters: previousFilters)
        if previousGroupBy == arrangement.groupBy {
            stageExit(from: previous, scope: previousScope, filters: presentedFiltersBeforeChange, animated: animated)
        }
    }

    private func stageExit(from previous: WorkspaceExplorerProjectionResult?,
                           scope previousScope: WorkspaceExplorerScope,
                           filters previousFilters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey],
                           animated: Bool) {
        guard animated, catalog?.liveMetadataPending != true else { return }
        let exitsUnassigned = collectionTarget == nil &&
            unassignedVisible(scope: previousScope, filters: previousFilters) &&
            !unassignedVisible(scope: scope, filters: activeArrangement.filters)
        exitTransition.stage(from: previous, to: projectedResult(), scope: previousScope,
            filters: previousFilters, exitsUnassigned: exitsUnassigned, animated: animated)
    }

    private func unassignedVisible(scope: WorkspaceExplorerScope,
                                   filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]) -> Bool {
        guard filters[.projectOwner] == nil, filters[.projectStatus] == nil,
              let projection else { return false }
        let workspaceFilters = filters.filter { $0.key == .repository || $0.key == .bmuxStatus }
        return projection.collection(target: .unassigned, scope: scope, groupBy: [],
            filters: workspaceFilters, now: .now, calendar: .current).visibleCounts.workspaces > 0
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
