import Foundation

/// Determines whether the active live workspace is hidden by Explorer's current view.
@MainActor
enum WorkspaceExplorerActiveWorkspaceVisibility {
    static func outsideTitle(model: WorkspaceExplorerCoordinator) -> String? {
        guard let catalog = model.catalog, let activeID = model.activeWorkspaceID,
              !catalog.liveMetadataPending,
              let item = catalog.items.first(where: { $0.id == activeID }),
              let result = model.result() else { return nil }
        if model.collectionTarget != nil {
            return result.visibleWorkspaceIDs.contains(activeID) ? nil : item.title
        }
        guard let workspace = catalog.workspaces.first(where: { $0.id == activeID }) else { return nil }
        let filters = model.presentedFilters
        let projectFiltersPresent = filters[.projectOwner] != nil || filters[.projectStatus] != nil
        let projectVisible = workspace.projectIDs.isEmpty ? !projectFiltersPresent :
            workspace.projectIDs.contains { result.visibleProjectIDs.contains($0) }
        let workspaceFilters = filters.filter { $0.key == .repository || $0.key == .bmuxStatus }
        let workspaceVisible = model.projection?.collection(target: .all, scope: model.presentedScope,
            groupBy: [], filters: workspaceFilters, now: model.activityArrangement.now, calendar: model.activityArrangement.calendar)
            .visibleWorkspaceIDs.contains(activeID) == true
        return projectVisible && workspaceVisible ? nil : item.title
    }
}
