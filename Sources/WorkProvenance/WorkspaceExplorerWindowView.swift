import AppKit
import SwiftUI

/// A separate, full-size native Explorer beside the existing workspace sidebar.
@MainActor
struct WorkspaceExplorerWindowView: View {
    @State private var model: WorkspaceExplorerCoordinator
    @State private var confirmsClearHistory = false

    init(loadHistory: @escaping WorkspaceExplorerCoordinator.Loader,
         reopenHistory: @escaping WorkspaceExplorerCoordinator.Reopener,
         activateWorkspace: @escaping WorkspaceExplorerCoordinator.Activator,
         loadSessions: @escaping WorkspaceExplorerCoordinator.SessionLoader,
         clearArchive: @escaping WorkspaceExplorerCoordinator.Clearer) {
        _model = State(initialValue: WorkspaceExplorerCoordinator(
            loadHistory: loadHistory, reopenHistory: reopenHistory,
            activateWorkspace: activateWorkspace, loadSessions: loadSessions,
            clearArchive: clearArchive))
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
                        if model.clearFailed {
                            notice(String(localized: "explorer.clearFailed", defaultValue:
                                "Explorer history could not be cleared. Try again."))
                        }
                        if model.catalog?.archiveAvailable == false {
                            notice(String(localized: "explorer.historyUnavailable", defaultValue:
                                "History could not be loaded. Showing open workspaces only; closed counts are unknown."))
                        } else if model.catalog?.partialLiveActivity == true {
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
            }
        }
        .frame(minWidth: 640, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await model.load() }
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
                        Button(collectionTitle(target)) { model.backFromHistory() }
                        Text("›").foregroundStyle(.secondary)
                    } else {
                        Text(collectionTitle(target))
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
            if model.historyID == nil { scopeControls }
        }
        .padding(16)
    }

    private var scopeControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                scopeButton(String(localized: "explorer.open", defaultValue: "Open"),
                    selected: model.scope.state == .open) { model.scope.state = .open }
                scopeButton(String(localized: "explorer.all", defaultValue: "All"),
                    selected: model.scope.state == .all) { model.scope.state = .all }
                scopeButton(String(localized: "explorer.closed", defaultValue: "Closed"),
                    selected: model.scope.state == .closed) { model.scope.state = .closed }
            }
            .padding(2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            Menu(periodTitle(model.scope.period)) {
                periodOption(.anyTime)
                periodOption(.last24Hours)
                periodOption(.today)
                periodOption(.last7Days)
            }
            Spacer()
        }
        .font(.system(size: 12))
    }

    private func scopeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(selected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func periodOption(_ period: WorkspaceExplorerScope.Period) -> some View {
        Button(periodTitle(period)) { model.scope.period = period }
    }

    private func periodTitle(_ period: WorkspaceExplorerScope.Period) -> String {
        switch period {
        case .anyTime: String(localized: "explorer.anyTime", defaultValue: "Any time")
        case .last24Hours: String(localized: "explorer.last24Hours", defaultValue: "Last 24 hours")
        case .today: String(localized: "explorer.today", defaultValue: "Today")
        case .last7Days: String(localized: "explorer.last7Days", defaultValue: "Last 7 days")
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = model.result() {
                HStack {
                    Text(String(format: result.counts.workspaces == 1 ?
                        String(localized: "explorer.overviewCountOne", defaultValue: "%d projects · %d workspace") :
                        String(localized: "explorer.overviewCount", defaultValue: "%d projects · %d workspaces"),
                        result.inScopeProjectIDs.count,
                        result.counts.workspaces))
                    Spacer()
                    Button(String(localized: "explorer.allWorkspaces", defaultValue: "All workspaces")) {
                        model.showCollection(.all)
                    }
                }
                .font(.system(size: 13)).foregroundStyle(.secondary)
                arrangementBar
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
                        scope: model.scope, openTotal: openTotal,
                        matchingCount: overviewFilters.isEmpty ? nil : unassigned.visibleCounts.workspaces,
                        onOpen: { model.showCollection(.unassigned) })
                        .frame(maxWidth: 300)
                }
                if result.visibleProjectIDs.isEmpty && result.counts.workspaces == 0 {
                    emptyCollection
                }
            }
        }
    }

    private func collection(target: WorkspaceExplorerCollectionTarget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(collectionTitle(target)).font(.system(size: 18, weight: .bold))
            if let result = model.result() {
                Text(String(format: result.counts.workspaces == 1 ?
                    String(localized: "explorer.workspaceCountOne", defaultValue: "%d workspace") :
                    String(localized: "explorer.workspaceCount", defaultValue: "%d workspaces"),
                    result.counts.workspaces))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                arrangementBar
                ForEach(Array(result.groups.enumerated()), id: \.offset) { _, group in
                    groupSection(group, path: "collection/\(String(reflecting: group.key))", overview: false,
                        matchingCounts: [:])
                }
                if result.visibleWorkspaceIDs.isEmpty { emptyCollection }
            }
        }
    }

    private var emptyCollection: some View {
        Group {
            if !model.activeArrangement.filters.isEmpty {
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
                } actions: {
                    Button(String(localized: "explorer.anyTime", defaultValue: "Any time")) {
                        model.scope.period = .anyTime
                    }
                }
            } else {
                ContentUnavailableView(String(localized: "explorer.noWorkspaces", defaultValue:
                    "No workspaces in this scope"), systemImage: "square.grid.2x2")
            }
        }
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
            overview: overview, collapsedPaths: arrangement.collapsedPaths,
            activeFilters: arrangement.filters,
            projectsByID: Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            itemsByID: Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            projectCounts: counts, projectOpenTotals: openTotals, scope: model.scope,
            matchingCounts: matchingCounts,
            onOpenProject: { model.showCollection(.project($0)) },
            onOpenWorkspace: { model.open($0) },
            onHistory: { model.showHistory($0.id) },
            onReopen: { item in Task { _ = await model.reopen(item) } },
            onCardFilter: { model.setFilter($0, value: $1) },
            onToggle: { model.toggleCollapsed($0) },
            onFocus: { model.setFilter($0, value: $1) })
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
                    onOpenLive: { model.open(item) },
                    onReopen: { Task { _ = await model.reopen(item) } })
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
