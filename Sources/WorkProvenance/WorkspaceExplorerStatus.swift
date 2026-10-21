import Foundation

/// A verified live status. Closed workspaces have a separate historical state.
enum WorkspaceExplorerStatus: Int, CaseIterable, Comparable {
    case error, needsInput, running, idle, disconnected, closedHistorical

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    static func derived(from sessions: [Self], connectionVerified: Bool) -> Self {
        guard connectionVerified else { return .disconnected }
        return sessions.filter { $0 != .closedHistorical && $0 != .disconnected }.min() ?? .idle
    }

    var archiveCode: String? {
        switch self {
        case .error: "error"
        case .needsInput: "needs_input"
        case .running: "running"
        case .idle: "idle"
        case .disconnected: "disconnected"
        case .closedHistorical: nil
        }
    }

    init?(archiveCode: String) {
        switch archiveCode {
        case "error": self = .error
        case "needs_input": self = .needsInput
        case "running": self = .running
        case "idle": self = .idle
        case "disconnected": self = .disconnected
        default: return nil
        }
    }

    /// Hook lifecycle data is used only while its connection or process identity is verified.
    @MainActor
    static func verified(of workspace: Workspace) -> WorkspaceExplorerStatus {
        if workspace.remoteDisplayTarget != nil && workspace.remoteConnectionState == .error {
            return .error
        }
        let remoteVerified = workspace.remoteDisplayTarget != nil &&
            workspace.remoteConnectionState == .connected
        var states: [WorkspaceExplorerStatus] = []
        var hasVerifiedProcess = false
        for (panelID, keys) in workspace.agentPIDKeysByPanelId where workspace.panels[panelID] != nil {
            for key in keys {
                let verified: Bool
                if workspace.remoteDisplayTarget != nil {
                    verified = remoteVerified
                } else if let pid = workspace.agentPIDs[key],
                          let recorded = workspace.agentPIDProcessIdentitiesByKey[key] {
                    verified = Workspace.agentPIDProcessIdentity(pid: pid) == recorded
                } else {
                    verified = false
                }
                guard verified else { continue }
                hasVerifiedProcess = true
                switch workspace.agentLifecycleStatesByPanelId[panelID]?[key] {
                case .needsInput: states.append(.needsInput)
                case .running: states.append(.running)
                case .idle: states.append(.idle)
                case .unknown, .none: break
                }
            }
        }
        return WorkspaceExplorerStatus.derived(
            from: states, connectionVerified: hasVerifiedProcess || remoteVerified)
    }
}
