import AppKit
import SwiftUI

/// A separate, full-size native Explorer beside the existing workspace sidebar.
@MainActor
struct WorkspaceExplorerWindowView: View {
    @State private var model: WorkspaceExplorerCoordinator
    @State private var confirmsClearHistory = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cardGeometry

    init(loadPresence: WorkspaceExplorerCoordinator.PresenceLoader? = nil,
         loadHistory: @escaping WorkspaceExplorerCoordinator.Loader,
         reopenHistory: @escaping WorkspaceExplorerCoordinator.Reopener,
         activateWorkspace: @escaping WorkspaceExplorerCoordinator.Activator,
         loadSessions: @escaping WorkspaceExplorerCoordinator.SessionLoader,
         loadEvidence: @escaping WorkspaceExplorerCoordinator.EvidenceLoader,
         loadMoreSessions: @escaping WorkspaceExplorerCoordinator.MoreSessionsLoader,
         clearArchive: @escaping WorkspaceExplorerCoordinator.Clearer,
         liveStatusWorkspaces: @escaping WorkspaceExplorerLiveStatusMonitor.WorkspaceSource) {
        _model = State(initialValue: WorkspaceExplorerCoordinator(
            loadHistory: loadHistory, loadPresence: loadPresence, reopenHistory: reopenHistory,
            activateWorkspace: activateWorkspace, loadSessions: loadSessions,
            loadEvidence: loadEvidence, loadMoreSessions: loadMoreSessions,
            clearArchive: clearArchive,
            liveStatusMonitor: WorkspaceExplorerLiveStatusMonitor(workspaces: liveStatusWorkspaces)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if model.isLoading && model.catalog == nil {
                ContentUnavailableView(String(localized: "explorer.loading", defaultValue: "Loading workspaces…"),
                    systemImage: "square.grid.2x2")
            } else if model.loadFailed && model.catalog == nil {
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
                        if let title = outsideActiveWorkspaceTitle {
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
                        if model.scope.state != .open, let catalog = model.catalog {
                            WorkspaceExplorerArchiveNotice(availability: catalog.archiveAvailability) {
                                Task { await model.load() }
                            }
                        }
                        if model.catalog?.archiveAvailability != .pending &&
                            model.catalog?.partialLiveActivity == true {
                            notice(String(localized: "explorer.partialActivity", defaultValue:
                                "Some live activity could not be verified. Time filters may omit those workspaces."))
                        }
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
        .task { await model.load() }
        .onDisappear { model.stopLiveStatusMonitoring() }
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

    private var outsideActiveWorkspaceTitle: String? {
        guard let catalog = model.catalog, let activeID = model.activeWorkspaceID,
              !catalog.liveMetadataPending,
              let item = catalog.items.first(where: { $0.id == activeID }),
              let result = model.result() else { return nil }
        if model.collectionTarget != nil {
            return result.visibleWorkspaceIDs.contains(activeID) ? nil : item.title
        }
        guard let workspace = catalog.workspaces.first(where: { $0.id == activeID }) else { return nil }
        let filters = model.overviewArrangement.filters
        let projectFiltersPresent = filters[.projectOwner] != nil || filters[.projectStatus] != nil
        let projectVisible = workspace.projectIDs.isEmpty ? !projectFiltersPresent :
            workspace.projectIDs.contains { result.visibleProjectIDs.contains($0) }
        let workspaceFilters = filters.filter { $0.key == .repository || $0.key == .bmuxStatus }
        let workspaceVisible = model.projection?.collection(target: .all, scope: model.scope,
            groupBy: [], filters: workspaceFilters, now: .now, calendar: .current)
            .visibleWorkspaceIDs.contains(activeID) == true
        return projectVisible && workspaceVisible ? nil : item.title
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
                        Button(collectionTitle(target)) { model.backFromHistory() }
                        Text("›").foregroundStyle(.secondary)
                    } else {
                        Text(collectionTitle(target))
                            .matchedGeometryEffect(id: "title:\(titleIdentity(target))", in: cardGeometry)
                    }
                } else {
                    Text(String(localized: "explorer.title", defaultValue: "Explorer"))
                }
                if let id = model.historyID,
                   let item = model.catalog?.items.first(where: { $0.id == id }) {
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
                    onState: { model.scope.state = $0 }, onPeriod: { model.scope.period = $0 })
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
                            scope: model.scope,
                            archiveAvailability: model.catalog?.archiveAvailability ?? .unavailable,
                            liveMetadataPending: model.catalog?.liveMetadataPending == true,
                            hasFilters: !model.activeArrangement.filters.isEmpty), id: \.self) { line in
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
                if model.catalog?.liveMetadataPending == true {
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
                      groupBy: [], filters: [:], now: .now, calendar: .current) {
                ForEach(Array(pending.groups.enumerated()), id: \.offset) { _, group in
                    groupSection(group, path: "pending/\(String(reflecting: group.key))", overview: false,
                        matchingCounts: [:])
                }
                if pending.visibleWorkspaceIDs.isEmpty { emptyCollection }
            }
        }
    }

    private func populatedOverview(_ result: WorkspaceExplorerProjectionResult) -> some View {
        Group {
            ForEach(Array(result.groups.enumerated()), id: \.offset) { _, group in
                groupSection(group, path: "overview/\(String(reflecting: group.key))", overview: true,
                    matchingCounts: model.activeArrangement.filters.isEmpty ? [:] :
                        result.matchingWorkspacesByProjectID)
            }
            let overviewFilters = model.activeArrangement.filters
            let unassignedFilters = overviewFilters.filter { $0.key == .repository || $0.key == .bmuxStatus }
            let hasProjectFilter = overviewFilters[.projectOwner] != nil || overviewFilters[.projectStatus] != nil
            let unassigned = model.projection?.collection(target: .unassigned, scope: model.scope,
                groupBy: [], filters: unassignedFilters, now: .now, calendar: .current)
            if !hasProjectFilter, let unassigned, unassigned.visibleCounts.workspaces > 0 {
                let openTotal = model.projection?.collection(target: .unassigned,
                    scope: WorkspaceExplorerScope(), groupBy: [], filters: [:],
                    now: .now, calendar: .current).counts.open ?? 0
                WorkspaceExplorerProjectCard(project: nil, counts: unassigned.counts,
                    workspaces: (model.catalog?.workspaces ?? []).filter { workspace in
                        workspace.projectIDs.isEmpty && model.scope.includes(workspace,
                            now: .now, calendar: .current)
                    },
                    scope: model.scope, archiveAvailability: model.catalog?.archiveAvailability ?? .unavailable,
                    openTotal: openTotal,
                    matchingCount: overviewFilters.isEmpty ? nil : unassigned.visibleCounts.workspaces,
                    isFocused: false, titleGeometry: cardGeometry,
                    onOpen: { model.showCollection(.unassigned) })
                    .frame(maxWidth: 300)
            }
            if result.visibleProjectIDs.isEmpty &&
                (hasProjectFilter || (unassigned?.visibleCounts.workspaces ?? 0) == 0) {
                emptyCollection
            }
        }
    }

    private func collection(target: WorkspaceExplorerCollectionTarget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = model.result() {
                Text(WorkspaceExplorerCountPresentation.collection(result, scope: model.scope,
                    archiveAvailability: model.catalog?.archiveAvailability ?? .unavailable,
                    liveMetadataPending: model.catalog?.liveMetadataPending == true,
                    hasFilters: !model.activeArrangement.filters.isEmpty &&
                        model.catalog?.liveMetadataPending != true))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                arrangementBar
                if model.catalog?.liveMetadataPending == true {
                    Text(WorkspaceExplorerCountPresentation.loadingProjects)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ForEach(Array(result.groups.enumerated()), id: \.offset) { _, group in
                    groupSection(group, path: "collection/\(String(reflecting: group.key))", overview: false,
                        matchingCounts: [:])
                }
                if result.visibleWorkspaceIDs.isEmpty { emptyCollection }
            } else if model.catalog?.liveMetadataPending == true {
                ContentUnavailableView(WorkspaceExplorerCountPresentation.loadingProjects,
                    systemImage: "clock")
            }
        }
    }

    private var emptyCollection: some View {
        Group {
            if model.catalog?.liveMetadataPending == true && model.scope.period != .anyTime {
                ContentUnavailableView(String(localized: "explorer.activityLoading", defaultValue:
                    "Loading workspace activity…"), systemImage: "clock")
            } else if model.catalog?.archiveAvailability == .pending &&
                (model.scope.state != .open || model.scope.period != .anyTime) {
                ContentUnavailableView(String(localized: "explorer.historyLoadingTitle", defaultValue:
                    "Loading retained history…"), systemImage: "clock")
            } else if model.catalog?.archiveAvailability == .unavailable && model.scope.state == .closed {
                ContentUnavailableView(String(localized: "explorer.historyUnavailableTitle", defaultValue:
                    "Retained history unavailable"), systemImage: "exclamationmark.triangle")
            } else if !model.activeArrangement.filters.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noFilterMatches", defaultValue:
                        "No workspaces match these filters"), systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button(String(localized: "explorer.clearFilters", defaultValue: "Clear filters")) {
                        model.clearFilters()
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
                        model.scope.period = .anyTime
                    }
                }
            } else if model.scope.state == .open {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noOpenWorkspaces", defaultValue:
                        "No open workspaces"), systemImage: "square.grid.2x2")
                } description: {
                    if model.catalog?.archiveAvailable == true {
                        Text(String(format: String(localized: "explorer.closedRetained", defaultValue:
                            "%d closed workspaces retained."), closedWorkspaceCount))
                    } else {
                        Text(model.catalog?.archiveAvailability.closedCountLabel ?? "")
                    }
                } actions: {
                    Button(String(localized: "explorer.showAll", defaultValue: "Show all")) {
                        model.scope.state = .all
                    }
                    Button(String(localized: "explorer.showClosed", defaultValue: "Show closed")) {
                        model.scope.state = .closed
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
            groupBy: [], filters: [:], now: .now, calendar: .current).counts.workspaces
    }

    private var closedWorkspaceCount: Int {
        guard let projection = model.projection else { return 0 }
        return projection.collection(target: model.collectionTarget ?? .all,
            scope: WorkspaceExplorerScope(state: .closed, period: .anyTime),
            groupBy: [], filters: [:], now: .now, calendar: .current).counts.closed
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
            projectsByID: Dictionary((model.catalog?.projects ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            canUndo: arrangement.canUndo,
            onGroupBy: { model.setGroupBy($0) },
            onFilter: { model.setFilter($0, value: $1) },
            onClear: { model.clearFilters() }, onUndo: { model.undo() })
    }

    private func groupSection(_ group: WorkspaceExplorerGroup, path: String, overview: Bool,
                              matchingCounts: [String: Int]) -> some View {
        let arrangement = model.activeArrangement
        let projects = model.catalog?.projects ?? []
        let items = model.catalog?.items ?? []
        let counts = Dictionary(projects.map { project in
            let count = model.projection?.collection(target: .project(project.id), scope: model.scope,
                groupBy: [], filters: [:], now: .now, calendar: .current).counts ??
                WorkspaceExplorerCounts([], closedKnown: false)
            return (project.id, count)
        }, uniquingKeysWith: { first, _ in first })
        let openTotals = Dictionary(projects.map { project in
            let total = model.projection?.collection(target: .project(project.id),
                scope: WorkspaceExplorerScope(), groupBy: [], filters: [:],
                now: .now, calendar: .current).counts.open ?? 0
            return (project.id, total)
        }, uniquingKeysWith: { first, _ in first })
        return WorkspaceExplorerGroupSection(group: group, depth: 0, path: path,
            cardGeometry: cardGeometry,
            overview: overview, collapsedPaths: arrangement.collapsedPaths,
            activeFilters: arrangement.filters,
            projectsByID: Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            itemsByID: Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            workspacesByID: Dictionary((model.catalog?.workspaces ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            projectCounts: counts, projectOpenTotals: openTotals, scope: model.scope,
            archiveAvailability: model.catalog?.archiveAvailability ?? .unavailable,
            matchingCounts: matchingCounts,
            focusedProjectID: model.overviewArrangement.focusedProjectID,
            activeWorkspaceID: model.activeWorkspaceID,
            reopenedWorkspaceID: model.reopenedWorkspaceID,
            metadataPending: model.catalog?.liveMetadataPending == true,
            onOpenProject: { model.showCollection(.project($0)) },
            onOpenWorkspace: { model.open($0) },
            onHistory: { model.showHistory($0.id) },
            onReopen: { item in Task { _ = await model.reopen(item) } },
            onCardFilter: { model.setFilter($0, value: $1) },
            onToggle: { model.toggleCollapsed($0) },
            onFocus: { model.setFilter($0, value: $1) })
    }

    private func titleIdentity(_ target: WorkspaceExplorerCollectionTarget) -> String {
        switch target {
        case .all: "all"
        case .unassigned: "unassigned"
        case .project(let id): id
        }
    }

    private func collectionTitle(_ target: WorkspaceExplorerCollectionTarget) -> String {
        switch target {
        case .all: String(localized: "explorer.allWorkspaces", defaultValue: "All workspaces")
        case .unassigned: String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces")
        case .project(let id): model.catalog?.projects.first(where: { $0.id == id })?.name ?? id
        }
    }

    private func history(id: String) -> some View {
        Group {
            if let item = model.catalog?.items.first(where: { $0.id == id }) {
                WorkspaceExplorerHistoryView(item: item, page: model.sessionsByWorkspaceID[id],
                    period: model.scope.period, loadFailed: model.sessionLoadFailed,
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
