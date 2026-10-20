import Foundation

extension WorkspaceExplorerDimension {
    var displayName: String {
        switch self {
        case .project: String(localized: "explorer.dimension.project", defaultValue: "Project")
        case .workspaceState: String(localized: "explorer.dimension.workspaceState", defaultValue: "Workspace state")
        case .repository: String(localized: "explorer.dimension.repository", defaultValue: "Repository")
        case .ticket: String(localized: "explorer.dimension.ticket", defaultValue: "Ticket")
        case .pullRequestOwner: String(localized: "explorer.dimension.prOwner", defaultValue: "PR owner")
        case .pullRequestStatus: String(localized: "explorer.dimension.prStatus", defaultValue: "PR status")
        case .ticketStatus: String(localized: "explorer.dimension.ticketStatus", defaultValue: "Ticket status")
        case .bmuxStatus: String(localized: "explorer.dimension.bmuxStatus", defaultValue: "bmux status")
        case .projectOwner: String(localized: "explorer.dimension.projectOwner", defaultValue: "Project owner")
        case .projectStatus: String(localized: "explorer.dimension.projectStatus", defaultValue: "Project status")
        }
    }
}
