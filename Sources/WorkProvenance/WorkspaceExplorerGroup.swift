import Foundation

/// Immutable grouped membership; collapsed state belongs to the view coordinator.
struct WorkspaceExplorerGroup {
    let dimension: WorkspaceExplorerDimension?
    let key: WorkspaceExplorerGroupKey?
    let value: String?
    /// Canonical value for Focus; project groups use IDs rather than display names.
    let filterValue: WorkspaceExplorerGroupKey?
    let projectIDs: [String]
    let workspaceIDs: [String]
    let counts: WorkspaceExplorerCounts
    let children: [WorkspaceExplorerGroup]
}
