import Foundation

/// Normalized logical workspace input, independent of live and PE storage types.
struct WorkspaceExplorerWorkspace: Identifiable {
    let id: String
    let title: String
    let projectIDs: [String]
    let repository: String?
    let tickets: [String]
    let ticketStatus: String?
    let pullRequestOwner: String?
    let pullRequestStatus: String?
    let hasPullRequest: Bool
    let lastActivityAt: Date?
    let isClosed: Bool
    let liveStatus: WorkspaceExplorerStatus
    let arrangedStatus: WorkspaceExplorerStatus

    var displayedStatus: WorkspaceExplorerStatus {
        isClosed ? .closedHistorical : liveStatus
    }

    var groupingStatus: WorkspaceExplorerStatus {
        isClosed ? .closedHistorical : arrangedStatus
    }
}
