import Testing
import BmuxFoundation

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct AgentHibernationPortalVisibilityTests {
    @Test func hiddenShellContentCannotBeReshownByLayoutReconciliation() throws {
        let workspace = Workspace()
        let panelID = try #require(workspace.focusedPanelId)
        let panel = try #require(workspace.terminalPanel(for: panelID))
        var previousStates = [workspace.id: true]

        for visible in [false, false, true, false] {
            let changes = WorkspacePortalRenderingPlan(
                previousStatesByWorkspaceId: previousStates,
                mountedWorkspaceIds: [workspace.id],
                orderedWorkspaceIds: [workspace.id],
                contentVisible: visible
            ).applying(to: &previousStates)
            for change in changes {
                workspace.setPortalRenderingEnabled(change.isEnabled, reason: "shellTabChange")
            }
            workspace.reconcileTerminalPortalVisibilityForCurrentRenderedLayout()
            #expect(panel.hostedView.debugPortalVisibleInUI == visible)
            if !visible { #expect(panel.hostedView.isHidden) }
        }
    }

    @Test func showingAutoResumePresentationDoesNotRestoreNonHibernatedTerminalPortal() throws {
        let workspace = Workspace()
        let panelId = try #require(workspace.focusedPanelId)
        let panel = try #require(workspace.terminalPanel(for: panelId))

        #expect(!panel.isAgentHibernated)
        panel.hostedView.setVisibleInUI(false)
        #expect(!panel.hostedView.debugPortalVisibleInUI)

        workspace.setAgentHibernationAutoResumePresentationVisible(false)
        workspace.setAgentHibernationAutoResumePresentationVisible(true)

        #expect(!panel.hostedView.debugPortalVisibleInUI)
    }
}
