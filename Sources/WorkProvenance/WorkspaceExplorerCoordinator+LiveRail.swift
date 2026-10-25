import Foundation

/// Projects Explorer visibility into the main workbench rail.
extension WorkspaceExplorerCoordinator {
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
