import Foundation

extension WorkspaceExplorerGroupKey {
    func displayName(projectsByID: [String: WorkspaceExplorerProject],
                     repositoryNamesByID: [String: String] = [:]) -> String {
        switch self {
        case .value(let value): return repositoryNamesByID[value] ?? value
        case .project(let id): return projectsByID[id]?.name ?? id
        case .unassigned: return String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces")
        case .workspaceState(let closed):
            return closed ? String(localized: "explorer.closed", defaultValue: "Closed") :
                String(localized: "explorer.open", defaultValue: "Open")
        case .bmuxStatus(let status):
            switch status {
            case .error: return String(localized: "explorer.status.error", defaultValue: "Error")
            case .needsInput: return String(localized: "explorer.status.needsInput", defaultValue: "Needs input")
            case .running: return String(localized: "explorer.status.running", defaultValue: "Running")
            case .idle: return String(localized: "explorer.status.idle", defaultValue: "Idle")
            case .disconnected: return String(localized: "explorer.status.disconnected", defaultValue: "Disconnected")
            case .closedHistorical: return String(localized: "explorer.status.historical", defaultValue: "Closed (historical)")
            }
        case .missing(let value), .multiple(let value):
            switch value {
            case "Unknown repository": return String(localized: "explorer.unknownRepository", defaultValue: "Unknown repository")
            case "Multiple repositories": return String(localized: "explorer.multipleRepositories", defaultValue: "Multiple repositories")
            case "No ticket": return String(localized: "explorer.noTicket", defaultValue: "No ticket")
            case "Multiple tickets": return String(localized: "explorer.multipleTickets", defaultValue: "Multiple tickets")
            case "Unknown ticket status": return String(localized: "explorer.unknownTicketStatus", defaultValue: "Unknown ticket status")
            case "No PR": return String(localized: "explorer.noPR", defaultValue: "No PR")
            case "Unknown PR owner": return String(localized: "explorer.unknownPROwner", defaultValue: "Unknown PR owner")
            case "Unknown PR status": return String(localized: "explorer.unknownPRStatus", defaultValue: "Unknown PR status")
            case "Multiple projects": return String(localized: "explorer.multipleProjects", defaultValue: "Multiple projects")
            case "Unknown project owner": return String(localized: "explorer.unknownProjectOwner", defaultValue: "Unknown project owner")
            case "Unknown project status": return String(localized: "explorer.unknownProjectStatus", defaultValue: "Unknown project status")
            default: return value
            }
        }
    }
}
