import Foundation

/// Keeps card labels live while status-based membership waits for explicit application.
struct WorkspaceExplorerStatusArrangement {
    private(set) var live: [String: WorkspaceExplorerStatus] = [:]
    private(set) var arranged: [String: WorkspaceExplorerStatus] = [:]

    mutating func observe(
        workspaceID: String,
        status: WorkspaceExplorerStatus,
        groupBy: [WorkspaceExplorerDimension],
        filters: [WorkspaceExplorerDimension: String]
    ) {
        let previous = live[workspaceID] ?? arranged[workspaceID] ?? status
        live[workspaceID] = status
        if arranged[workspaceID] == nil { arranged[workspaceID] = previous }
        if !groupBy.contains(.bmuxStatus) && filters[.bmuxStatus] == nil {
            arranged[workspaceID] = status
        }
    }

    func liveStatus(for workspaceID: String) -> WorkspaceExplorerStatus? { live[workspaceID] }
    func arrangedStatus(for workspaceID: String) -> WorkspaceExplorerStatus? { arranged[workspaceID] }

    var pendingWorkspaceIDs: Set<String> {
        Set(live.keys.filter { live[$0] != arranged[$0] })
    }

    mutating func applyPending() {
        arranged = live
    }

    mutating func remove(workspaceID: String) {
        live.removeValue(forKey: workspaceID)
        arranged.removeValue(forKey: workspaceID)
    }
}
