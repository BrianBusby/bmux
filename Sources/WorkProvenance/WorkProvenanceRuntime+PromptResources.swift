import Foundation

extension WorkProvenanceRuntime {
    /// Resolves exact panel identity so delayed evidence cannot use Workspace's focused-panel fallback.
    func promptWorkspaceActions(workspaceID: String?, surfaceID: String?) -> WorkProvenancePromptWorkspaceActions? {
        guard lifecycleState == .ready || lifecycleState == .starting,
              let workspaceID = workspaceID.flatMap(UUID.init(uuidString:)),
              let surfaceID = surfaceID.flatMap(UUID.init(uuidString:)),
              let match = Self.workspaceMatch(matching: workspaceID, in: workspaceResolutionTabManagers(for: workspaceID)),
              let panel = match.workspace.panels[surfaceID], panel.panelType == .terminal else { return nil }
        let workspace = match.workspace
        let manager = match.tabManager
        let stableID = workspace.stableId
        let panelIdentity = ObjectIdentifier(panel)
        let isCurrent: () -> Bool = { [weak self, weak workspace, weak manager] in
            guard let self, self.lifecycleState == .ready || self.lifecycleState == .starting,
                  let workspace, let manager, workspace.stableId == stableID,
                  manager.tabs.contains(where: { $0 === workspace }),
                  let currentPanel = workspace.panels[surfaceID] else { return false }
            return ObjectIdentifier(currentPanel) == panelIdentity
        }
        return WorkProvenancePromptWorkspaceActions(
            stableWorkspaceID: stableID, surfaceID: surfaceID, isCurrent: isCurrent,
            applyResources: { [weak workspace, weak manager] prompt in
                guard isCurrent(), let workspace, let manager else { return false }
                manager.refreshSubmittedPullRequestMentionIfNeeded(
                    workspaceId: workspace.id,
                    record: workspace.recordSubmittedPullRequestMention(prompt, surfaceId: surfaceID)
                )
                return true
            }
        )
    }
}
