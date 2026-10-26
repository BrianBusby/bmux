import AppKit
import SwiftUI

/// Explorer content used in the workbench and the standalone window.
@MainActor
struct WorkspaceExplorerWindowView: View {
    @State private var model: WorkspaceExplorerCoordinator
    @State private var confirmsClearHistory = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cardGeometry
    let liveNavigation: WorkspaceExplorerLiveNavigation?
    let provenanceStartupFailed: @MainActor () -> Bool
    let restartApp: @MainActor () throws -> Void
    let isEmbedded: Bool

    init(model: WorkspaceExplorerCoordinator,
         provenanceStartupFailed: @escaping @MainActor () -> Bool,
         restartApp: @escaping @MainActor () throws -> Void,
         liveNavigation: WorkspaceExplorerLiveNavigation? = nil,
         isEmbedded: Bool = false) {
        _model = State(initialValue: model)
        self.provenanceStartupFailed = provenanceStartupFailed
        self.restartApp = restartApp
        self.liveNavigation = liveNavigation
        self.isEmbedded = isEmbedded
    }

    init(loadPresence: WorkspaceExplorerCoordinator.PresenceLoader? = nil,
         loadHistory: @escaping WorkspaceExplorerCoordinator.Loader,
         loadMoreHistory: WorkspaceExplorerCoordinator.MoreHistoryLoader? = nil,
         reopenHistory: @escaping WorkspaceExplorerCoordinator.Reopener,
         activateWorkspace: @escaping WorkspaceExplorerCoordinator.Activator,
         loadSessions: @escaping WorkspaceExplorerCoordinator.SessionLoader,
         loadEvidence: @escaping WorkspaceExplorerCoordinator.EvidenceLoader,
         loadMoreSessions: @escaping WorkspaceExplorerCoordinator.MoreSessionsLoader,
         clearArchive: @escaping WorkspaceExplorerCoordinator.Clearer,
         liveStatusWorkspaces: @escaping WorkspaceExplorerLiveStatusMonitor.WorkspaceSource,
         workspaceTabManagers: WorkspaceExplorerWorkspaceChangeMonitor.TabManagers? = nil,
         provenanceStartupFailed: @escaping @MainActor () -> Bool = { false },
         restartApp: @escaping @MainActor () throws -> Void = {},
         liveNavigation: WorkspaceExplorerLiveNavigation? = nil,
         isEmbedded: Bool = false) {
        self.liveNavigation = liveNavigation
        self.provenanceStartupFailed = provenanceStartupFailed
        self.restartApp = restartApp
        self.isEmbedded = isEmbedded
        _model = State(initialValue: WorkspaceExplorerCoordinator(
            loadHistory: loadHistory, loadMoreHistory: loadMoreHistory,
            loadPresence: loadPresence, reopenHistory: reopenHistory,
            activateWorkspace: activateWorkspace,
            onOpenLive: { item, target, title in
                liveNavigation?.opened(item: item, target: target, from: title, loadSessions: loadSessions) },
            loadSessions: loadSessions,
            loadEvidence: loadEvidence, loadMoreSessions: loadMoreSessions,
            clearArchive: clearArchive,
            liveStatusMonitor: WorkspaceExplorerLiveStatusMonitor(workspaces: liveStatusWorkspaces),
            workspaceChangeMonitor: workspaceTabManagers.map {
                WorkspaceExplorerWorkspaceChangeMonitor(tabManagers: $0)
            }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if model.isLoading && model.presentedCatalog == nil {
                ContentUnavailableView(String(localized: "explorer.loading", defaultValue: "Loading workspaces…"),
                    systemImage: "square.grid.2x2")
            } else if model.loadFailed && model.presentedCatalog == nil {
                ContentUnavailableView {
                    Label(String(localized: "explorer.loadFailed", defaultValue: "Explorer could not load"),
                        systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(String(localized: "explorer.retry", defaultValue: "Retry")) {
                        Task { await model.load() }
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        WorkspaceExplorerProvenanceNotice(
                            startupFailed: provenanceStartupFailed(),
                            partialLiveActivity: model.presentedCatalog?.archiveAvailability != .pending &&
                                model.presentedCatalog?.partialLiveActivity == true,
                            restartApp: restartApp,
                            onRetry: { Task { await model.load() } })
                        if let title = WorkspaceExplorerActiveWorkspaceVisibility.outsideTitle(model: model) {
                            notice(String(format: String(localized: "explorer.activeOutsideView", defaultValue:
                                "Active workspace “%@” is outside the current scope or filters. It stays active."),
                                title))
                        }
                        if model.pendingStatusChangeCount > 0 {
                            HStack {
                                Text(String(format: String(localized: "explorer.statusChanged", defaultValue:
                                    "%d workspaces changed status"), model.pendingStatusChangeCount))
                                Button(String(localized: "explorer.updateArrangement", defaultValue:
                                    "Update arrangement")) { model.applyPendingStatusArrangement() }
                            }
                            .font(.system(size: 12)).padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        }
                        if model.activityArrangement.hasPendingUpdate {
                            HStack {
                                Text(String(localized: "explorer.arrangementChanged", defaultValue:
                                    "Explorer arrangement changed"))
                                Button(String(localized: "explorer.updateArrangement", defaultValue:
                                    "Update arrangement")) { model.applyPendingActivityArrangement() }
                            }
                            .font(.system(size: 12)).padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        }
                        if let title = model.reopenedTitle {
                            notice(String(format: String(localized: "explorer.reopenedConfirmation", defaultValue:
                                "Reopened “%@” — history retained, no agent resumed"), title))
                        }
                        if model.reopenFailed {
                            notice(String(localized: "explorer.reopenFailed", defaultValue:
                                "Workspace could not be reopened. Its history remains available."))
                        }
                        if model.clearFailed {
                            notice(String(localized: "explorer.clearFailed", defaultValue:
                                "Explorer history could not be cleared. Try again."))
                        }
                        if model.scope.state != .open, let catalog = model.presentedCatalog {
                            WorkspaceExplorerArchiveNotice(availability: catalog.archiveAvailability) {
                                Task { await model.load() }
                            }
                        }
                        WorkspaceExplorerPendingWorkspaceSection(items: model.visiblePendingWorkspaceItems,
                            activeWorkspaceID: model.activeWorkspaceID,
                            onOpen: { model.open($0) })
                        if let id = model.historyID {
                            history(id: id)
                        } else {
                            collection
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollPosition(id: Binding(
                    get: { model.activeArrangement.scrollAnchorID },
                    set: { model.setScrollAnchor($0) }
                ))
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.25),
                    value: model.activeArrangement.groupBy)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.2),
                    value: model.activeArrangement.filters)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.2),
                    value: model.activeArrangement.collapsedPaths)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.28),
                    value: model.collectionTarget)
            }
        }
        .frame(minWidth: isEmbedded ? 0 : 640, minHeight: isEmbedded ? 0 : 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            if !isEmbedded {
                WindowAccessor { window in liveNavigation?.register(window: window, coordinator: model) }
            }
        }
        .task {
            model.startWorkspaceChangeMonitoring()
            await model.load()
        }
        .onDisappear {
            if !isEmbedded { model.stopLiveStatusMonitoring() }
        }
        .task(id: model.historyID) {
            if let id = model.historyID { await model.loadHistorySessions(for: id) }
        }
        .confirmationDialog(String(localized: "explorer.clearConfirmTitle", defaultValue: "Clear Explorer history?"),
            isPresented: $confirmsClearHistory) {
            Button(String(localized: "explorer.clearHistory", defaultValue: "Clear Explorer history"), role: .destructive) {
                Task { await model.clearHistory() }
            }
        } message: {
            Text(String(localized: "explorer.clearConfirmMessage", defaultValue:
                "Archived Explorer cards and snapshots will be removed. Provenance session evidence remains."))
        }
    }

    private var header: some View {
        WorkspaceExplorerHeaderView(model: model, confirmsClearHistory: $confirmsClearHistory)
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = model.result() {
                Text(WorkspaceExplorerCountPresentation.collection(result, scope: model.presentedScope,
                    archiveAvailability: model.presentedCatalog?.archiveAvailability ?? .unavailable,
                    liveMetadataPending: model.presentedCatalog?.liveMetadataPending == true,
                    hasFilters: !model.presentedFilters.isEmpty &&
                        model.presentedCatalog?.liveMetadataPending != true,
                    historyHasMore: model.hasMoreHistory))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                arrangementBar
                if model.presentedCatalog?.liveMetadataPending == true {
                    Text(WorkspaceExplorerCountPresentation.loadingProjects)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ForEach(result.groups, id: \.identity) { group in
                    groupSection(group, path: "collection/\(group.identity)")
                }
                if model.scope.state != .open && model.hasMoreHistory {
                    HStack(spacing: 8) {
                        Button(model.historyPageFailed ?
                            String(localized: "explorer.retryMoreHistory", defaultValue: "Retry loading history") :
                            String(localized: "explorer.loadMoreHistory", defaultValue: "Load more history")) {
                            Task { await model.loadMoreHistoryPage() }
                        }
                        .disabled(model.historyPageLoading)
                        if model.historyPageLoading { ProgressView().controlSize(.small) }
                    }
                }
                if result.visibleWorkspaceIDs.isEmpty && model.visiblePendingWorkspaceItems.isEmpty &&
                    !model.hasMoreHistory && !model.historyPageLoading { emptyCollection }
            } else if model.presentedCatalog?.liveMetadataPending == true {
                ContentUnavailableView(WorkspaceExplorerCountPresentation.loadingProjects,
                    systemImage: "clock")
            }
        }
    }

    private var emptyCollection: some View {
        WorkspaceExplorerEmptyCollectionView(
            liveMetadataPending: model.presentedCatalog?.liveMetadataPending == true,
            scope: model.scope,
            archiveAvailability: model.presentedCatalog?.archiveAvailability ?? .unavailable,
            archiveAvailable: model.presentedCatalog?.archiveAvailable == true,
            hasFilters: !model.activeArrangement.filters.isEmpty,
            anyTimeWorkspaceCount: anyTimeWorkspaceCount,
            closedWorkspaceCount: closedWorkspaceCount,
            closedCountLabel: model.presentedCatalog?.archiveAvailability.closedCountLabel ?? "",
            onClearFilters: { model.clearFilters(animated: !reduceMotion) },
            onAnyTime: { model.setScopePeriod(.anyTime, animated: !reduceMotion) },
            onShowAll: { model.setScopeState(.all, animated: !reduceMotion) },
            onShowClosed: { model.setScopeState(.closed, animated: !reduceMotion) })
    }

    private var anyTimeWorkspaceCount: Int {
        guard let projection = model.projection else { return 0 }
        return projection.collection(target: model.collectionTarget ?? .all,
            scope: WorkspaceExplorerScope(state: .all, period: .anyTime),
            groupBy: [], filters: [:], now: model.activityArrangement.now, calendar: model.activityArrangement.calendar).counts.workspaces
    }

    private var closedWorkspaceCount: Int {
        guard let projection = model.projection else { return 0 }
        return projection.collection(target: model.collectionTarget ?? .all,
            scope: WorkspaceExplorerScope(state: .closed, period: .anyTime),
            groupBy: [], filters: [:], now: model.activityArrangement.now, calendar: model.activityArrangement.calendar).counts.closed
    }

    private var arrangementBar: some View {
        let atRoot = model.collectionTarget == nil
        let dimensions: [WorkspaceExplorerDimension] = [.repository, .ticket, .pullRequestOwner,
            .pullRequestStatus, .ticketStatus, .bmuxStatus] +
            (model.scope.state == .all ? [.workspaceState] : []) +
            (atRoot ? [.project] : [])
        let filterDimensions: [WorkspaceExplorerDimension] = [.bmuxStatus, .repository] +
            (atRoot ? [.project] : []) + [.pullRequestOwner]
        let arrangement = model.activeArrangement
        return WorkspaceExplorerArrangementBar(groupBy: arrangement.groupBy, filters: arrangement.filters,
            availableDimensions: dimensions,
            filterDimensions: filterDimensions,
            filterOptions: model.presentedCatalog?.filterOptions(dimensions: filterDimensions,
                target: model.collectionTarget ?? .all, scope: model.scope, inScopeWorkspaceIDs: model.result()?.inScopeWorkspaceIDs ?? [],
                now: model.activityArrangement.now, calendar: model.activityArrangement.calendar) ?? [:],
            projectsByID: Dictionary((model.presentedCatalog?.projects ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            repositoryNamesByID: model.presentedCatalog?.repositoryNamesByID ?? [:],
            canUndo: arrangement.canUndo,
            onGroupBy: { model.setGroupBy($0) },
            onFilter: { model.setFilter($0, value: $1, animated: !reduceMotion) },
            onClear: { model.clearFilters(animated: !reduceMotion) },
            onUndo: { model.undo(animated: !reduceMotion) })
    }

    private func groupSection(_ group: WorkspaceExplorerGroup, path: String) -> some View {
        let arrangement = model.activeArrangement
        let collectionDimensions: Set<WorkspaceExplorerDimension>
        if case .project = model.collectionTarget {
            collectionDimensions = [.project]
        } else {
            collectionDimensions = []
        }
        let projects = model.presentedCatalog?.projects ?? []
        let items = model.presentedCatalog?.items ?? []
        return WorkspaceExplorerGroupSection(group: group, depth: 0, path: path,
            cardGeometry: cardGeometry,
            collapsedPaths: arrangement.collapsedPaths,
            activeFilters: model.presentedFilters,
            groupedDimensions: Set(arrangement.groupBy).union(collectionDimensions),
            projectsByID: Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            repositoryNamesByID: model.presentedCatalog?.repositoryNamesByID ?? [:],
            itemsByID: Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            workspacesByID: Dictionary((model.presentedCatalog?.workspaces ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            scope: model.presentedScope, exitingWorkspaceIDs: model.exitingWorkspaceIDs,
            activeWorkspaceID: model.activeWorkspaceID,
            reopenedWorkspaceID: model.reopenedWorkspaceID,
            metadataPending: model.presentedCatalog?.liveMetadataPending == true,
            onOpenWorkspace: { model.open($0) },
            onHistory: { model.showHistory($0.id) },
            onReopen: { item in Task { _ = await model.reopen(item) } },
            onCardFilter: { model.setFilter($0, value: $1, animated: !reduceMotion) },
            onToggle: { model.toggleCollapsed($0) },
            onFocus: { model.setFilter($0, value: $1, animated: !reduceMotion) },
            onCardInteractionChanged: { model.cardInteractionChanged(id: $0, active: $1) })
    }

    private func history(id: String) -> some View {
        Group {
            if let item = model.presentedCatalog?.items.first(where: { $0.id == id }) {
                WorkspaceExplorerHistoryView(item: item,
                    repositoryNamesByID: model.presentedCatalog?.repositoryNamesByID ?? [:],
                    page: model.sessionsByWorkspaceID[id],
                    period: model.scope.period, now: model.activityArrangement.now, loadFailed: model.sessionLoadFailed,
                    evidenceBySessionID: model.evidenceBySessionID,
                    evidenceLoadingIDs: model.evidenceLoadingIDs,
                    evidenceFailedIDs: model.evidenceFailedIDs,
                    onOpenLive: { model.open(item) },
                    onReopen: { Task { _ = await model.reopen(item) } },
                    onLoadEvidence: { sessionID in Task { await model.loadSessionEvidence(for: sessionID) } },
                    onLoadMore: { Task { await model.loadMoreHistorySessions(for: id) } })
                    .id(id)
            }
        }
    }

    private func notice(_ message: String) -> some View {
        Text(message).font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
