import Foundation

enum WorkspaceExplorerDimension: Hashable {
    case project, workspaceState, repository, ticket, pullRequestOwner
    case pullRequestStatus, ticketStatus, bmuxStatus, projectOwner, projectStatus

    var isOverviewDimension: Bool {
        switch self {
        case .repository, .projectOwner, .projectStatus: true
        default: false
        }
    }

    func workspaceKey(_ workspace: WorkspaceExplorerWorkspace, projectNames: [String: String]) -> String {
        switch self {
        case .project:
            if workspace.projectIDs.isEmpty { return "Unassigned" }
            if workspace.projectIDs.count > 1 { return "Multiple projects" }
            return projectNames[workspace.projectIDs[0]] ?? workspace.projectIDs[0]
        case .workspaceState: return workspace.isClosed ? "Closed" : "Open"
        case .repository: return workspace.repository ?? "Unknown repository"
        case .ticket:
            if workspace.tickets.isEmpty { return "No ticket" }
            return workspace.tickets.count > 1 ? "Multiple tickets" : workspace.tickets[0]
        case .ticketStatus:
            if workspace.tickets.isEmpty { return "No ticket" }
            if workspace.tickets.count > 1 { return "Multiple tickets" }
            return workspace.ticketStatus ?? "Unknown ticket status"
        case .pullRequestOwner:
            return workspace.hasPullRequest ? (workspace.pullRequestOwner ?? "Unknown PR owner") : "No PR"
        case .pullRequestStatus:
            return workspace.hasPullRequest ? (workspace.pullRequestStatus ?? "Unknown PR status") : "No PR"
        case .bmuxStatus:
            switch workspace.groupingStatus {
            case .error: return "Error"
            case .needsInput: return "Needs input"
            case .running: return "Running"
            case .idle: return "Idle"
            case .disconnected: return "Disconnected"
            case .closedHistorical: return "Closed (historical)"
            }
        case .projectOwner, .projectStatus: return ""
        }
    }

    func projectKey(_ project: WorkspaceExplorerProject, workspaces: [WorkspaceExplorerWorkspace]) -> String {
        switch self {
        case .repository:
            let repositories = Set(workspaces.compactMap(\.repository))
            if repositories.isEmpty { return "Unknown repository" }
            if let onlyRepository = repositories.first, repositories.count == 1 { return onlyRepository }
            return "Multiple repositories"
        case .projectOwner: return project.owner ?? "Unknown project owner"
        case .projectStatus: return project.status ?? "Unknown project status"
        default: return ""
        }
    }

    func precedes(_ lhs: String, _ rhs: String) -> Bool {
        if self == .bmuxStatus {
            let order = ["Error", "Needs input", "Running", "Idle", "Disconnected", "Closed (historical)"]
            return (order.firstIndex(of: lhs) ?? order.count) < (order.firstIndex(of: rhs) ?? order.count)
        }
        if self == .workspaceState { return lhs == "Open" && rhs == "Closed" }
        let lhsMissing = ["No ", "Unknown ", "Multiple ", "Unassigned"].contains { lhs.hasPrefix($0) }
        let rhsMissing = ["No ", "Unknown ", "Multiple ", "Unassigned"].contains { rhs.hasPrefix($0) }
        if lhsMissing != rhsMissing { return !lhsMissing }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}
