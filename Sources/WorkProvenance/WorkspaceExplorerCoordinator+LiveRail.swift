import Foundation

/// A removable constraint carried from Explorer into the live workspace rail.
struct WorkspaceExplorerRailFilter: Identifiable, Equatable {
    enum Kind: Equatable {
        case collection(WorkspaceExplorerCollectionTarget)
        case state(WorkspaceExplorerScope.State)
        case period(WorkspaceExplorerScope.Period)
        case dimension(WorkspaceExplorerDimension, WorkspaceExplorerGroupKey)
    }

    let kind: Kind
    let label: String

    var id: String {
        switch kind {
        case .collection: "collection"
        case .state: "state"
        case .period: "period"
        case .dimension(let dimension, _): "dimension:\(dimension)"
        }
    }
}

/// Projects Explorer visibility into the main workbench rail.
extension WorkspaceExplorerCoordinator {
    var activeRailFilters: [WorkspaceExplorerRailFilter] {
        var result: [WorkspaceExplorerRailFilter] = []
        if let collectionTarget {
            result.append(.init(kind: .collection(collectionTarget), label: String(format:
                String(localized: "workspaceRail.collectionFilter", defaultValue: "Collection: %@"),
                collectionTarget.title(projects: presentedCatalog?.projects ?? []))))
        }
        if scope.state != .open {
            result.append(.init(kind: .state(scope.state), label: String(format:
                String(localized: "workspaceRail.stateFilter", defaultValue: "State: %@"), scope.stateLabel)))
        }
        if scope.period != .anyTime {
            result.append(.init(kind: .period(scope.period), label: String(format:
                String(localized: "workspaceRail.activityFilter", defaultValue: "Activity: %@"), scope.periodLabel)))
        }
        let filters = activeArrangement.filters
        guard !filters.isEmpty else { return result }
        let projectsByID = Dictionary((presentedCatalog?.projects ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        let repositoryNamesByID = presentedCatalog?.repositoryNamesByID ?? [:]
        for (dimension, key) in filters.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            let value = key.displayName(projectsByID: projectsByID,
                repositoryNamesByID: dimension == .repository ? repositoryNamesByID : [:])
            result.append(.init(kind: .dimension(dimension, key), label: String(format:
                String(localized: "workspaceRail.dimensionFilter", defaultValue: "%1$@: %2$@"),
                dimension.displayName, value)))
        }
        return result
    }

    func removeRailFilter(_ filter: WorkspaceExplorerRailFilter) {
        switch filter.kind {
        case .collection(let target) where collectionTarget == target:
            showOverview()
        case .state(let state) where scope.state == state:
            setScopeState(.open)
        case .period(let period) where scope.period == period:
            setScopePeriod(.anyTime)
        case .dimension(let dimension, let key) where activeArrangement.filters[dimension] == key:
            setFilter(dimension, value: nil)
        default:
            break
        }
    }

    /// Live tab identities in the current Explorer scope, including unassigned workspaces.
    var visibleLiveWorkspaceIDs: [UUID]? {
        guard let catalog = presentedCatalog else { return nil }
        return runtimeIDs(catalog: catalog, pendingItems: visiblePendingWorkspaceItems,
            target: collectionTarget, scope: presentedScope, filters: presentedFilters,
            now: activityArrangement.now, calendar: activityArrangement.calendar)
    }

    private func runtimeIDs(catalog: WorkspaceExplorerCatalog,
                    pendingItems: [WorkspaceExplorerHistoryItem],
                    target: WorkspaceExplorerCollectionTarget?,
                    scope: WorkspaceExplorerScope,
                    filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey],
                    now: Date, calendar: Calendar) -> [UUID] {
        let workspaceFilters = filters.filter { $0.key != .projectOwner && $0.key != .projectStatus }
        let matching = catalog.projection.collection(target: target ?? .all,
            scope: scope, groupBy: [], filters: workspaceFilters, now: now, calendar: calendar)
        let hasProjectFilter = filters[.projectOwner] != nil || filters[.projectStatus] != nil
        let visibleProjects = target == nil && hasProjectFilter
            ? Set(catalog.projection.overview(scope: scope, groupBy: [], filters: filters,
                now: now, calendar: calendar).visibleProjectIDs) : []
        let visibleStableIDs = Set(matching.visibleWorkspaceIDs)
        let result = catalog.items.compactMap { item -> UUID? in
            guard visibleStableIDs.contains(item.id), let runtimeID = item.liveWorkspaceID else { return nil }
            if target == nil && hasProjectFilter {
                let projectIDs = item.display?.projectLinks.map(\.id) ?? []
                guard projectIDs.contains(where: visibleProjects.contains) else { return nil }
            }
            return runtimeID
        }
        return result + pendingItems.compactMap(\.liveWorkspaceID)
    }
}
