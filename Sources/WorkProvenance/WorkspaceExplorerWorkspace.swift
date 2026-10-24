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

    func withLiveStatus(_ status: WorkspaceExplorerStatus) -> Self {
        Self(id: id, title: title, projectIDs: projectIDs, repository: repository,
            tickets: tickets, ticketStatus: ticketStatus, pullRequestOwner: pullRequestOwner,
            pullRequestStatus: pullRequestStatus, hasPullRequest: hasPullRequest,
            lastActivityAt: lastActivityAt, isClosed: isClosed, liveStatus: status,
            arrangedStatus: arrangedStatus)
    }

    var displayedStatus: WorkspaceExplorerStatus {
        isClosed ? .closedHistorical : liveStatus
    }

    var groupingStatus: WorkspaceExplorerStatus {
        isClosed ? .closedHistorical : arrangedStatus
    }
}
