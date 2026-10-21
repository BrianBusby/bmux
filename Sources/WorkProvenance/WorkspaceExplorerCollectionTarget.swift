import Foundation

/// Distinguishes a real project ID from the two Explorer fallback collections.
enum WorkspaceExplorerCollectionTarget: Equatable {
    case all
    case unassigned
    case project(String)

    var titleIdentity: String {
        switch self {
        case .all: "all"
        case .unassigned: "unassigned"
        case .project(let id): id
        }
    }

    func title(projects: [WorkspaceExplorerProject]) -> String {
        switch self {
        case .all: String(localized: "explorer.allWorkspaces", defaultValue: "All workspaces")
        case .unassigned: String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces")
        case .project(let id): projects.first(where: { $0.id == id })?.name ?? id
        }
    }
}
