import Foundation

/// Counts before and after filters stay separate so card and header labels remain consistent.
struct WorkspaceExplorerProjectionResult {
    let groups: [WorkspaceExplorerGroup]
    let inScopeProjectIDs: [String]
    let visibleProjectIDs: [String]
    let inScopeWorkspaceIDs: [String]
    let visibleWorkspaceIDs: [String]
    let counts: WorkspaceExplorerCounts
    let visibleCounts: WorkspaceExplorerCounts
    let matchingWorkspacesByProjectID: [String: Int]
}
