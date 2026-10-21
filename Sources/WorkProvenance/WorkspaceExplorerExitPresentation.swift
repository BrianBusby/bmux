import Foundation

/// Holds the old Explorer result while cards excluded by a user change fade out.
struct WorkspaceExplorerExitPresentation {
    let result: WorkspaceExplorerProjectionResult
    let scope: WorkspaceExplorerScope
    let filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    let exitingProjectIDs: Set<String>
    let exitsUnassigned: Bool
    let exitingWorkspaceIDs: Set<String>
}
