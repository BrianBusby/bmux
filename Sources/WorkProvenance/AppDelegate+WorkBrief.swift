import BmuxWorkBrief
import Foundation

@MainActor
extension AppDelegate {
    /// Reads current live facts through the existing Explorer and PE public SDK services.
    func loadWorkBrief() async -> WorkBriefSnapshot {
        do {
            let result = try await loadWorkspaceExplorerLiveBrief()
            let ids = Array(result.items.prefix(32)).compactMap { UUID(uuidString: $0.id) }
            var surfaces: [UUID: String] = [:]
            var partial = result.items.count > ids.count
            if let associationStore = workProvenanceRuntime?.workspaceCodingAgentSessionAssociationStore {
                for id in ids {
                    switch await associationStore.refreshedAssociation(stableWorkspaceID: id) {
                    case .available(let association, let readiness):
                        if let surfaceID = association.surfaceID, readiness.status == .available {
                            surfaces[id] = surfaceID
                        }
                    case .failed, .unavailable:
                        partial = true
                    case .notFound:
                        break
                    }
                }
            } else {
                partial = true
            }
            return WorkBriefLocalAdapter().snapshot(result, surfaceIDs: surfaces,
                associationPartial: partial)
        } catch {
            let fallback = WorkBriefLocalAdapter().snapshot(workspaceExplorerPresence())
            let unavailable = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
            return WorkBriefSnapshot(localWorkspaces: fallback.localWorkspaces,
                localHealth: WorkBriefSourceHealth(state: .failed, checkedAt: Date(),
                    reasonCode: "local_refresh_failed"),
                linearHealth: unavailable, githubHealth: unavailable, slackHealth: unavailable)
        }
    }

    /// User-requested workspace selection through the existing shared action path.
    func workBriefJump(stableID: UUID, runtimeID: UUID) -> Bool {
        guard workBriefWorkspace(stableID: stableID, runtimeID: runtimeID) != nil else { return false }
        activateWorkspaceExplorerWorkspace(runtimeID: runtimeID)
        return true
    }

    /// User-requested highlight only for a surface still owned by the exact workspace.
    func workBriefHighlight(stableID: UUID, runtimeID: UUID, surfaceID: String) -> Bool {
        guard let panelID = UUID(uuidString: surfaceID),
              let workspace = workBriefWorkspace(stableID: stableID, runtimeID: runtimeID),
              workspace.panels[panelID] != nil else { return false }
        activateWorkspaceExplorerWorkspace(runtimeID: runtimeID)
        workspace.triggerFocusFlash(panelId: panelID)
        return true
    }

    private func workBriefWorkspace(stableID: UUID, runtimeID: UUID) -> Workspace? {
        mainWindowContexts.values.flatMap { $0.tabManager.tabs }.first {
            $0.stableId == stableID && $0.id == runtimeID
        }
    }
}
