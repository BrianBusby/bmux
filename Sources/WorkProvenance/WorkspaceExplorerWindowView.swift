import AppKit
import SwiftUI

/// A separate, full-size native Explorer beside the existing workspace sidebar.
@MainActor
struct WorkspaceExplorerWindowView: View {
    @State private var model: WorkspaceExplorerCoordinator
    @State private var confirmsClearHistory = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cardGeometry
    let liveNavigation: WorkspaceExplorerLiveNavigation?
    let provenanceStartupFailed: @MainActor () -> Bool
    let restartApp: @MainActor () throws -> Void

    init(loadPresence: WorkspaceExplorerCoordinator.PresenceLoader? = nil,
         loadHistory: @escaping WorkspaceExplorerCoordinator.Loader,
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
         liveNavigation: WorkspaceExplorerLiveNavigation? = nil) {
        self.liveNavigation = liveNavigation
        self.provenanceStartupFailed = provenanceStartupFailed
        self.restartApp = restartApp
        _model = State(initialValue: WorkspaceExplorerCoordinator(
            loadHistory: loadHistory, loadPresence: loadPresence, reopenHistory: reopenHistory,
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
                        } else if let target = model.collectionTarget {
                            collection(target: target)
                        } else {
                            overview
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
        .frame(minWidth: 640, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowAccessor { window in liveNavigation?.register(window: window, coordinator: model) })
        .task {
            model.startWorkspaceChangeMonitoring()
            await model.load()
        }
        .onDisappear {
            model.stopLiveStatusMonitoring()
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if model.collectionTarget != nil {
                    Button(String(localized: "explorer.allProjects", defaultValue: "All projects")) {
                        model.showOverview()
                    }
                    Text("›").foregroundStyle(.secondary)
                }
                if let target = model.collectionTarget {
                    if model.historyID != nil {
                        Button(target.title(projects: model.presentedCatalog?.projects ?? [])) { model.backFromHistory() }
                        Text("›").foregroundStyle(.secondary)
                    } else {
                        Text(target.title(projects: model.presentedCatalog?.projects ?? []))
                            .matchedGeometryEffect(id: "title:\(target.titleIdentity)", in: cardGeometry)
                    }
                } else {
                    Text(String(localized: "explorer.title", defaultValue: "Explorer"))
                }
                if let id = model.historyID,
                   let item = model.presentedCatalog?.items.first(where: { $0.id == id }) {
                    Text(item.title)
                    Text(String(localized: "explorer.readOnlyTag", defaultValue: "READ-ONLY HISTORY"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(model.scope.summary)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(String(localized: "explorer.refresh", defaultValue: "Refresh Explorer"))
                Menu {
                    Button(String(localized: "explorer.clearHistory", defaultValue: "Clear Explorer history")) {
                        confirmsClearHistory = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "explorer.moreActions", defaultValue: "Explorer actions"))
            }
            .font(.system(size: 18, weight: .bold))
            if model.historyID == nil {
                WorkspaceExplorerScopeControls(scope: model.scope,
                    onState: { model.setScopeState($0, animated: !reduceMotion) },
                    onPeriod: { model.setScopePeriod($0, animated: !reduceMotion) })
            }
        }
        .padding(16)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = model.result() {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(WorkspaceExplorerCountPresentation.overviewLines(result,
                            scope: model.presentedScope,
                            archiveAvailability: model.presentedCatalog?.archiveAvailability ?? .unavailable,
                            liveMetadataPending: model.presentedCatalog?.liveMetadataPending == true,
                            hasFilters: !model.presentedFilters.isEmpty), id: \.self) { line in
                            Text(line)
                        }
                    }
                    Spacer()
                    Button(String(localized: "explorer.allWorkspaces", defaultValue: "All workspaces")) {
                        model.showCollection(.all)
                    }
                }
                .font(.system(size: 13)).foregroundStyle(.secondary)
                arrangementBar
                if model.presentedCatalog?.liveMetadataPending == true {
                    pendingOverview
                } else {
                    populatedOverview(result)
                }
            }
        }
    }

    private var pendingOverview: some View {
        Group {
            if model.scope.period != .anyTime {
                ContentUnavailableView(WorkspaceExplorerCountPresentation.loadingActivity,
                    systemImage: "clock")
            } else if model.scope.state == .closed {
                ContentUnavailableView(String(localized: "explorer.historyLoadingTitle", defaultValue:
                    "Loading retained history…"), systemImage: "clock")
            } else if !model.activeArrangement.filters.isEmpty {
                ContentUnavailableView(WorkspaceExplorerCountPresentation.loadingProjects,
                    systemImage: "clock")
            } else if let pending = model.projection?.collection(target: .all, scope: model.scope,
                      groupBy: [], filters: [:], now: model.activityArrangement.now, calendar: model.activityArrangement.calendar) {
                ForEach(pending.groups, id: \.identity) { group in
                    groupSection(group, path: "pending/\(group.identity)", overview: false,
                        matchingCounts: [:])
                }
                if pending.visibleWorkspaceIDs.isEmpty && model.visiblePendingWorkspaceItems.isEmpty { emptyCollection }
            }
        }
    }
    private func populatedOverview(_ result: WorkspaceExplorerProjectionResult) -> some View {
        Group {
            ForEach(result.groups, id: \.identity) { group in
                groupSection(group, path: "overview/\(group.identity)", overview: true,
                    matchingCounts: model.presentedFilters.isEmpty ? [:] :
                        result.matchingWorkspacesByProjectID)
            }
            let overviewFilters = model.presentedFilters
            let unassignedFilters = overviewFilters.filter { $0.key == .repository || $0.key == .bmuxStatus }
            let hasProjectFilter = overviewFilters[.projectOwner] != nil || overviewFilters[.projectStatus] != nil
            let unassigned = model.projection?.collection(target: .unassigned, scope: model.presentedScope,
                groupBy: [], filters: unassignedFilters, now: model.activityArrangement.now, calendar: model.activityArrangement.calendar)
            if !hasProjectFilter, let unassigned, unassigned.visibleCounts.workspaces > 0 {
                let openTotal = model.projection?.collection(target: .unassigned,
                    scope: WorkspaceExplorerScope(), groupBy: [], filters: [:],
                    now: model.activityArrangement.now, calendar: model.activityArrangement.calendar).counts.open ?? 0
                WorkspaceExplorerProjectCard(project: nil, counts: unassigned.counts,
                    workspaces: (model.presentedCatalog?.workspaces ?? []).filter { workspace in
                        workspace.projectIDs.isEmpty && model.presentedScope.includes(workspace,
                            now: model.activityArrangement.now, calendar: model.activityArrangement.calendar)
                    },
                    repositoryNamesByID: model.presentedCatalog?.repositoryNamesByID ?? [:],
                    scope: model.presentedScope, archiveAvailability: model.presentedCatalog?.archiveAvailability ?? .unavailable,
                    openTotal: openTotal,
                    matchingCount: overviewFilters.isEmpty ? nil : unassigned.visibleCounts.workspaces,
                    isFocused: false, titleGeometry: cardGeometry,
                    onOpen: { model.showCollection(.unassigned) },
                    onInteractionChanged: { model.cardInteractionChanged(id: "unassigned", active: $0) })
                    .frame(maxWidth: 300)
                    .opacity(model.exitsUnassigned ? 0 : 1)
                    .allowsHitTesting(!model.exitsUnassigned)
                    .accessibilityHidden(model.exitsUnassigned)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.17),
                        value: model.exitsUnassigned)
            }
            if model.visiblePendingWorkspaceItems.isEmpty && result.visibleProjectIDs.isEmpty &&
                (hasProjectFilter || (unassigned?.visibleCounts.workspaces ?? 0) == 0) {
                emptyCollection
            }
        }
    }

    private func collection(target: WorkspaceExplorerCollectionTarget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = model.result() {
                Text(WorkspaceExplorerCountPresentation.collection(result, scope: model.presentedScope,
                    archiveAvailability: model.presentedCatalog?.archiveAvailability ?? .unavailable,
                    liveMetadataPending: model.presentedCatalog?.liveMetadataPending == true,
                    hasFilters: !model.presentedFilters.isEmpty &&
                        model.presentedCatalog?.liveMetadataPending != true))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                arrangementBar
                if model.presentedCatalog?.liveMetadataPending == true {
                    Text(WorkspaceExplorerCountPresentation.loadingProjects)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ForEach(result.groups, id: \.identity) { group in
                    groupSection(group, path: "collection/\(group.identity)", overview: false,
                        matchingCounts: [:])
                }
                if result.visibleWorkspaceIDs.isEmpty && model.visiblePendingWorkspaceItems.isEmpty { emptyCollection }
            } else if model.presentedCatalog?.liveMetadataPending == true {
                ContentUnavailableView(WorkspaceExplorerCountPresentation.loadingProjects,
                    systemImage: "clock")
            }
        }
    }

    private var emptyCollection: some View {
        Group {
            if model.presentedCatalog?.liveMetadataPending == true && model.scope.period != .anyTime {
                ContentUnavailableView(String(localized: "explorer.activityLoading", defaultValue:
                    "Loading workspace activity…"), systemImage: "clock")
            } else if model.presentedCatalog?.archiveAvailability == .pending &&
                (model.scope.state != .open || model.scope.period != .anyTime) {
                ContentUnavailableView(String(localized: "explorer.historyLoadingTitle", defaultValue:
                    "Loading retained history…"), systemImage: "clock")
            } else if model.presentedCatalog?.archiveAvailability == .unavailable && model.scope.state == .closed {
                ContentUnavailableView(String(localized: "explorer.historyUnavailableTitle", defaultValue:
                    "Retained history unavailable"), systemImage: "exclamationmark.triangle")
            } else if !model.activeArrangement.filters.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noFilterMatches", defaultValue:
                        "No workspaces match these filters"), systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button(String(localized: "explorer.clearFilters", defaultValue: "Clear filters")) {
                        model.clearFilters(animated: !reduceMotion)
                    }
                }
            } else if model.scope.period != .anyTime {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noActivity", defaultValue: "No activity in this period"),
                        systemImage: "clock")
                } description: {
                    Text(String(format: String(localized: "explorer.anyTimeTotal", defaultValue:
                        "%d workspaces at any time. Capture may also be incomplete."), anyTimeWorkspaceCount))
                } actions: {
                    Button(String(localized: "explorer.anyTime", defaultValue: "Any time")) {
                        model.setScopePeriod(.anyTime, animated: !reduceMotion)
                    }
                }
            } else if model.scope.state == .open {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noOpenWorkspaces", defaultValue:
                        "No open workspaces"), systemImage: "square.grid.2x2")
                } description: {
                    if model.presentedCatalog?.archiveAvailable == true {
                        Text(String(format: String(localized: "explorer.closedRetained", defaultValue:
                            "%d closed workspaces retained."), closedWorkspaceCount))
                    } else {
                        Text(model.presentedCatalog?.archiveAvailability.closedCountLabel ?? "")
                    }
                } actions: {
                    Button(String(localized: "explorer.showAll", defaultValue: "Show all")) {
                        model.setScopeState(.all, animated: !reduceMotion)
                    }
                    Button(String(localized: "explorer.showClosed", defaultValue: "Show closed")) {
                        model.setScopeState(.closed, animated: !reduceMotion)
                    }
                }
            } else {
                ContentUnavailableView(String(localized: "explorer.noWorkspaces", defaultValue:
                    "No workspaces in this scope"), systemImage: "square.grid.2x2")
            }
        }
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
        let dimensions: [WorkspaceExplorerDimension]
        if model.collectionTarget == nil {
            dimensions = [.repository, .projectOwner, .projectStatus]
        } else {
            dimensions = [.repository, .ticket, .pullRequestOwner, .pullRequestStatus,
                .ticketStatus, .bmuxStatus] +
                (model.scope.state == .all ? [.workspaceState] : []) +
                (model.collectionTarget == .all ? [.project] : [])
        }
        let arrangement = model.activeArrangement
        return WorkspaceExplorerArrangementBar(groupBy: arrangement.groupBy, filters: arrangement.filters,
            availableDimensions: dimensions,
            projectsByID: Dictionary((model.presentedCatalog?.projects ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            repositoryNamesByID: model.presentedCatalog?.repositoryNamesByID ?? [:],
            canUndo: arrangement.canUndo,
            onGroupBy: { model.setGroupBy($0) },
            onFilter: { model.setFilter($0, value: $1, animated: !reduceMotion) },
            onClear: { model.clearFilters(animated: !reduceMotion) },
            onUndo: { model.undo(animated: !reduceMotion) })
    }

    private func groupSection(_ group: WorkspaceExplorerGroup, path: String, overview: Bool,
                              matchingCounts: [String: Int]) -> some View {
        let arrangement = model.activeArrangement
        let collectionDimensions: Set<WorkspaceExplorerDimension>
        if case .project = model.collectionTarget {
            collectionDimensions = [.project]
        } else {
            collectionDimensions = []
        }
        let projects = model.presentedCatalog?.projects ?? []
        let items = model.presentedCatalog?.items ?? []
        let counts = Dictionary(projects.map { project in
            let count = model.projection?.collection(target: .project(project.id), scope: model.presentedScope,
                groupBy: [], filters: [:], now: model.activityArrangement.now, calendar: model.activityArrangement.calendar).counts ??
                WorkspaceExplorerCounts([], closedKnown: false)
            return (project.id, count)
        }, uniquingKeysWith: { first, _ in first })
        let openTotals = Dictionary(projects.map { project in
            let total = model.projection?.collection(target: .project(project.id),
                scope: WorkspaceExplorerScope(), groupBy: [], filters: [:],
                now: model.activityArrangement.now, calendar: model.activityArrangement.calendar).counts.open ?? 0
            return (project.id, total)
        }, uniquingKeysWith: { first, _ in first })
        return WorkspaceExplorerGroupSection(group: group, depth: 0, path: path,
            cardGeometry: cardGeometry,
            overview: overview, collapsedPaths: arrangement.collapsedPaths,
            activeFilters: model.presentedFilters,
            groupedDimensions: Set(arrangement.groupBy).union(collectionDimensions),
            projectsByID: Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            repositoryNamesByID: model.presentedCatalog?.repositoryNamesByID ?? [:],
            itemsByID: Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            workspacesByID: Dictionary((model.presentedCatalog?.workspaces ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            projectCounts: counts, projectOpenTotals: openTotals, scope: model.presentedScope,
            now: model.activityArrangement.now, calendar: model.activityArrangement.calendar,
            archiveAvailability: model.presentedCatalog?.archiveAvailability ?? .unavailable,
            matchingCounts: matchingCounts,
            exitingProjectIDs: model.exitingProjectIDs, exitingWorkspaceIDs: model.exitingWorkspaceIDs,
            focusedProjectID: model.overviewArrangement.focusedProjectID,
            activeWorkspaceID: model.activeWorkspaceID,
            reopenedWorkspaceID: model.reopenedWorkspaceID,
            metadataPending: model.presentedCatalog?.liveMetadataPending == true,
            onOpenProject: { model.showCollection(.project($0)) },
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
