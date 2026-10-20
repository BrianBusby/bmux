import Foundation
import ProvenanceEngineContracts

/// Immutable input captured from bmux's live workspace owner on the main actor.
struct WorkspaceExplorerLiveWorkspace {
    let stableID: UUID
    let runtimeID: UUID
    let title: String
    let createdAt: Date
    let colorHex: String?
    let display: ProvenanceWorkspaceDisplayRecord?
    let lastActivityAt: Date?
    let liveStatus: WorkspaceExplorerStatus

    init(stableID: UUID, runtimeID: UUID, title: String, createdAt: Date,
         colorHex: String?, display: ProvenanceWorkspaceDisplayRecord?, lastActivityAt: Date?,
         liveStatus: WorkspaceExplorerStatus = .disconnected) {
        self.stableID = stableID
        self.runtimeID = runtimeID
        self.title = title
        self.createdAt = createdAt
        self.colorHex = colorHex
        self.display = display
        self.lastActivityAt = lastActivityAt
        self.liveStatus = liveStatus
    }

    /// Hook lifecycle data is used only while its connection or process identity is verified.
    @MainActor
    static func verifiedStatus(of workspace: Workspace) -> WorkspaceExplorerStatus {
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
