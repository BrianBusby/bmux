import Foundation

/// A verified live status. Closed workspaces have a separate historical state.
enum WorkspaceExplorerStatus: Int, CaseIterable, Comparable {
    case error, needsInput, running, idle, disconnected, closedHistorical

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    static func derived(from sessions: [Self], connectionVerified: Bool) -> Self {
        guard connectionVerified else { return .disconnected }
        return sessions.filter { $0 != .closedHistorical && $0 != .disconnected }.min() ?? .idle
    }
}
