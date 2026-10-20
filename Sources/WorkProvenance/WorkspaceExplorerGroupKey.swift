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

    func label(projectNames: [String: String] = [:]) -> String {
        switch self {
        case .value(let value), .missing(let value), .multiple(let value): return value
        case .project(let id): return projectNames[id] ?? id
        case .unassigned: return "Unassigned"
        case .workspaceState(let isClosed): return isClosed ? "Closed" : "Open"
        case .bmuxStatus(let status):
            switch status {
            case .error: return "Error"
            case .needsInput: return "Needs input"
            case .running: return "Running"
            case .idle: return "Idle"
            case .disconnected: return "Disconnected"
            case .closedHistorical: return "Closed (historical)"
            }
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
