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

    func workspaceKey(_ workspace: WorkspaceExplorerWorkspace) -> WorkspaceExplorerGroupKey {
        switch self {
        case .project:
            if workspace.projectIDs.isEmpty { return .unassigned }
            if workspace.projectIDs.count > 1 { return .multiple("Multiple projects") }
            return .project(workspace.projectIDs[0])
        case .workspaceState: return .workspaceState(isClosed: workspace.isClosed)
        case .repository: return workspace.repository.map(WorkspaceExplorerGroupKey.value) ?? .missing("Unknown repository")
        case .ticket:
            if workspace.tickets.isEmpty { return .missing("No ticket") }
            return workspace.tickets.count > 1 ? .multiple("Multiple tickets") : .value(workspace.tickets[0])
        case .ticketStatus:
            if workspace.tickets.isEmpty { return .missing("No ticket") }
            if workspace.tickets.count > 1 { return .multiple("Multiple tickets") }
            return workspace.ticketStatus.map(WorkspaceExplorerGroupKey.value) ?? .missing("Unknown ticket status")
        case .pullRequestOwner:
            guard workspace.hasPullRequest else { return .missing("No PR") }
            return workspace.pullRequestOwner.map(WorkspaceExplorerGroupKey.value) ?? .missing("Unknown PR owner")
        case .pullRequestStatus:
            guard workspace.hasPullRequest else { return .missing("No PR") }
            return workspace.pullRequestStatus.map(WorkspaceExplorerGroupKey.value) ?? .missing("Unknown PR status")
        case .bmuxStatus:
            return .bmuxStatus(workspace.groupingStatus)
        case .projectOwner, .projectStatus: return .missing("")
        }
    }

    func projectKey(_ project: WorkspaceExplorerProject, workspaces: [WorkspaceExplorerWorkspace]) -> WorkspaceExplorerGroupKey {
        switch self {
        case .repository:
            let repositories = Set(workspaces.compactMap(\.repository))
            if repositories.isEmpty { return .missing("Unknown repository") }
            if let onlyRepository = repositories.first, repositories.count == 1 { return .value(onlyRepository) }
            return .multiple("Multiple repositories")
        case .projectOwner: return project.owner.map(WorkspaceExplorerGroupKey.value) ?? .missing("Unknown project owner")
        case .projectStatus: return project.status.map(WorkspaceExplorerGroupKey.value) ?? .missing("Unknown project status")
        default: return .missing("")
        }
    }

    func precedes(_ lhs: WorkspaceExplorerGroupKey, _ rhs: WorkspaceExplorerGroupKey,
                  projectNames: [String: String] = [:],
                  repositoryNames: [String: String] = [:]) -> Bool {
        if self == .bmuxStatus {
            if case .bmuxStatus(let left) = lhs, case .bmuxStatus(let right) = rhs { return left < right }
        }
        if self == .workspaceState {
            if case .workspaceState(let left) = lhs, case .workspaceState(let right) = rhs { return !left && right }
        }
        let lhsFallback = lhs.isFallback
        let rhsFallback = rhs.isFallback
        if lhsFallback != rhsFallback { return !lhsFallback }
        let names = self == .repository ? repositoryNames : [:]
        let left = lhs.label(projectNames: projectNames, repositoryNames: names)
        let right = rhs.label(projectNames: projectNames, repositoryNames: names)
        if left == right { return lhs.sortIdentity < rhs.sortIdentity }
        return left.localizedStandardCompare(right) == .orderedAscending
    }
}
