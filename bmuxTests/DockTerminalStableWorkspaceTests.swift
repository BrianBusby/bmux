import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct DockTerminalStableWorkspaceTests {
    @Test("Moving a live terminal into a workspace Dock preserves destination stable workspace identity")
    @MainActor
    func attachIntoWorkspaceDockPreservesDestinationStableWorkspaceID() throws {
        let sourceWorkspace = Workspace(title: "Source")
        let destinationWorkspace = Workspace(title: "Destination")
        let terminalPanel = TerminalPanel(
            workspaceId: sourceWorkspace.id,
            stableWorkspaceId: sourceWorkspace.stableId
        )
        let dock = destinationWorkspace.dockSplit
        defer {
            terminalPanel.close()
            dock.closeAllPanels()
            sourceWorkspace.teardownAllPanels()
            destinationWorkspace.teardownAllPanels()
        }

        let rootPane = try #require(dock.bonsplitController.allPaneIds.first)
        let transfer = Workspace.DetachedSurfaceTransfer(
            sourceWorkspaceId: sourceWorkspace.id,
            panelId: terminalPanel.id,
            panel: terminalPanel,
            title: terminalPanel.displayTitle,
            icon: terminalPanel.displayIcon,
            iconImageData: nil,
            kind: "terminal",
            isLoading: false,
            isPinned: false,
            directory: nil,
            directoryIsTrustedRemoteReport: false,
            directoryDisplayLabel: nil,
            ttyName: nil,
            cachedTitle: nil,
            customTitle: nil,
            customTitleSource: nil,
            manuallyUnread: false,
            restoredUnreadIndicator: nil,
            restorableAgent: nil,
            restorableAgentResumeState: nil,
            restoredResumeSessionWorkingDirectory: nil,
            resumeBinding: nil,
            agentRuntime: nil,
            isRemoteTerminal: false,
            remoteRelayPort: nil,
            remotePTYSessionID: nil,
            remoteCleanupConfiguration: nil
        )

        let attachedPanelId = dock.attachDetachedSurface(transfer, inPane: rootPane, focus: false)

        #expect(attachedPanelId == terminalPanel.id)
        #expect(terminalPanel.workspaceId == destinationWorkspace.id)
        #expect(terminalPanel.surface.stableWorkspaceId == destinationWorkspace.stableId)
        #expect(
            terminalPanel.surface.startupEnvironmentValue("BMUX_STABLE_WORKSPACE_ID") ==
                destinationWorkspace.stableId.uuidString
        )
        #expect(
            terminalPanel.surface.startupEnvironmentValue("CMUX_STABLE_WORKSPACE_ID") ==
                destinationWorkspace.stableId.uuidString
        )
    }
}
