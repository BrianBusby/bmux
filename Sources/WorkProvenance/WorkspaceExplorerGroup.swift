import Foundation

/// Immutable grouped membership; collapsed state belongs to the view coordinator.
struct WorkspaceExplorerGroup {
    let dimension: WorkspaceExplorerDimension?
    let value: String?
    let projectIDs: [String]
    let workspaceIDs: [String]
    let counts: WorkspaceExplorerCounts
    let children: [WorkspaceExplorerGroup]
}
