import Foundation

/// A grouping and filter identity that cannot collide with a fallback label.
enum WorkspaceExplorerGroupKey: Hashable {
    case value(String)
    case missing(String)
    case multiple(String)
    case workspaceState(isClosed: Bool)
    case bmuxStatus(WorkspaceExplorerStatus)
    case project(String)
    case unassigned

    func label(projectNames: [String: String] = [:],
               repositoryNames: [String: String] = [:]) -> String {
        switch self {
        case .value(let value): return repositoryNames[value] ?? value
        case .missing, .multiple:
            return displayName(projectsByID: [:], repositoryNamesByID: repositoryNames)
        case .project(let id): return projectNames[id] ?? id
        case .unassigned, .workspaceState, .bmuxStatus:
            return displayName(projectsByID: [:], repositoryNamesByID: repositoryNames)
        }
    }

    func supportsFocus(in dimension: WorkspaceExplorerDimension, overview: Bool) -> Bool {
        guard case .multiple = self else { return true }
        return !(dimension == .project || (overview && dimension == .repository))
    }

    var isFallback: Bool {
        switch self {
        case .missing, .multiple, .unassigned: true
        default: false
        }
    }

    var sortIdentity: String {
        switch self {
        case .project(let id): return id
        default: return label()
        }
    }
}
