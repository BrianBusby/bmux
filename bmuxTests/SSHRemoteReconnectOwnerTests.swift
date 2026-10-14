import AppKit
import BmuxControlSocket
import BmuxCore
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct SSHRemoteReconnectOwnerTests {
    @Test(arguments: [WorkspaceRemoteConnectionState.connected, .reconnecting], [false, true])
    func unboundTerminalPreservesSessionStateOnFailedRespawn(
        state: WorkspaceRemoteConnectionState, ended: Bool
    ) throws {
        try withWorkspace(state: state) { workspace, _ in
            let original = try #require(workspace.focusedTerminalPanel)
            let unbound = TerminalPanel(workspaceId: workspace.id)
            workspace.panels[unbound.id] = unbound
            if ended { workspace.pendingRemoteTerminalChildExitSurfaceIds.insert(unbound.id) }
            let count = workspace.activeRemoteTerminalSessionCount

            #expect(!workspace.reconnectRemoteConnection(surfaceId: unbound.id))

            #expect(workspace.panels[unbound.id] as? TerminalPanel === unbound)
            #expect(workspace.panels[original.id] as? TerminalPanel === original)
            #expect(workspace.activeRemoteTerminalSessionCount == count)
            #expect(!workspace.isRemoteTerminalSurface(unbound.id))
            #expect(workspace.pendingRemoteTerminalChildExitSurfaceIds.contains(unbound.id) == ended)
            #expect(workspace.remoteConnectionState == state)
        }
    }

    @Test(arguments: [WorkspaceRemoteConnectionState.connected, .reconnecting])
    func endedPaneReplacementKeepsIdentityAndWorkspaceConnection(state: WorkspaceRemoteConnectionState) throws {
        try withWorkspace(state: state) { workspace, _ in
            let original = try #require(workspace.focusedTerminalPanel)
            let sibling = try #require(workspace.newTerminalSplit(from: original.id, orientation: .horizontal, focus: false))
            workspace.markRemoteTerminalSessionEnded(surfaceId: original.id, relayPort: 64007)
            #expect(workspace.isRemoteTerminalSurface(sibling.id))
            #expect(!workspace.isRemoteTerminalSurface(original.id))
            let pane = try #require(workspace.paneId(forPanelId: original.id))
            let tab = try #require(workspace.surfaceIdFromPanelId(original.id))
            let panelIDs = Set(workspace.panels.keys)
            workspace.pendingRemoteTerminalChildExitSurfaceIds.insert(original.id)

            #expect(workspace.reconnectRemoteConnection(surfaceId: original.id))

            let replacement = try #require(workspace.terminalPanel(for: original.id))
            #expect(replacement !== original)
            #expect(Set(workspace.panels.keys) == panelIDs)
            #expect(workspace.paneId(forPanelId: replacement.id) == pane)
            #expect(workspace.surfaceIdFromPanelId(replacement.id) == tab)
            #expect(workspace.focusedPanelId == original.id)
            #expect(replacement.surface.initialCommand == "/usr/bin/true")
            #expect(workspace.isRemoteTerminalSurface(original.id))
            #expect(workspace.activeRemoteTerminalSessionCount == 2)
            #expect(workspace.terminalPanel(for: sibling.id) === sibling)
            #expect(!workspace.pendingRemoteTerminalChildExitSurfaceIds.contains(original.id))
            #expect(workspace.remoteConnectionState == state)
        }
    }

    @Test(arguments: ["missing", "unbound", "empty-command"])
    func socketRejectsFailedTargetedRespawnWithoutReplacingAnotherSurface(target: String) throws {
        try withWorkspace(startupCommand: target == "empty-command" ? nil : "/usr/bin/true") { workspace, controller in
            let original = try #require(workspace.focusedTerminalPanel)
            var targetID = target == "empty-command" ? original.id : UUID()
            if target == "unbound" {
                let unbound = TerminalPanel(workspaceId: workspace.id)
                workspace.panels[unbound.id] = unbound
                targetID = unbound.id
            }
            let panelIDs = Set(workspace.panels.keys)
            let sessionCount = workspace.activeRemoteTerminalSessionCount
            workspace.pendingRemoteTerminalChildExitSurfaceIds.insert(targetID)
            let coordinator = ControlCommandCoordinator(context: controller)
            let response = coordinator.handle(ControlRequest(id: .int(1), method: "workspace.remote.reconnect", params: [
                "workspace_id": .string(workspace.id.uuidString),
                "surface_id": .string(targetID.uuidString),
            ]))
            guard case .err(let code, let message, .object(let data)) = response else {
                Issue.record("failed targeted respawn must return an RPC error")
                return
            }
            #expect(code == "invalid_state")
            #expect(!message.isEmpty)
            #expect(data["workspace_id"] == .string(workspace.id.uuidString))
            #expect(data["surface_id"] == .string(targetID.uuidString))
            #expect(workspace.focusedTerminalPanel === original)
            #expect(Set(workspace.panels.keys) == panelIDs)
            #expect(workspace.activeRemoteTerminalSessionCount == sessionCount)
            #expect(workspace.pendingRemoteTerminalChildExitSurfaceIds.contains(targetID))
        }
    }

    @Test func workspaceReconnectKeepsAcceptedNonRespawningResult() throws {
        try withWorkspace { workspace, controller in
            let original = try #require(workspace.focusedTerminalPanel)
            let coordinator = ControlCommandCoordinator(context: controller)
            let response = coordinator.handle(ControlRequest(id: .int(1), method: "workspace.remote.reconnect", params: [
                "workspace_id": .string(workspace.id.uuidString),
            ]))
            guard case .ok(.object(let payload)) = response else {
                Issue.record("workspace-level reconnect remains accepted without replacing a connected surface")
                return
            }
            #expect(payload["workspace_id"] == .string(workspace.id.uuidString))
            #expect(workspace.focusedTerminalPanel === original)
            #expect(workspace.remoteConnectionState == .connected)
        }
    }

    @Test func contextMenuUsesNativeReplacementWithoutSendingInputToEndedShell() throws {
        try withWorkspace { workspace, _ in
            let original = try #require(workspace.focusedTerminalPanel)
            let sibling = try #require(workspace.newTerminalSplit(from: original.id, orientation: .horizontal, focus: false))
            workspace.markRemoteTerminalSessionEnded(surfaceId: original.id, relayPort: 64007)
            let view = original.hostedView.surfaceView
            let menu = NSMenu()
            view.appendReconnectRemotePaneMenuItem(to: menu)
            let item = try #require(menu.items.first { $0.action != nil })
            let action = try #require(item.action)
            #expect(item.target === view)
            _ = view.perform(action, with: item)
            let replacement = try #require(workspace.terminalPanel(for: original.id))
            #expect(replacement !== original)
            #expect(replacement.surface.initialCommand == "/usr/bin/true")
            #expect(workspace.terminalPanel(for: sibling.id) === sibling)
            #expect(workspace.panels.count == 2)
        }
    }

    private func withWorkspace(
        state: WorkspaceRemoteConnectionState = .connected,
        startupCommand: String? = "/usr/bin/true",
        body: (Workspace, TerminalController) throws -> Void
    ) throws {
        // Keep global routing probes within one synchronous MainActor lifetime.
        let previousApp = AppDelegate.shared
        let controller = TerminalController.shared
        let previousManager = controller.activeTabManagerForCallerNotification()
        let app = AppDelegate()
        let manager = TabManager(initialWorkingDirectory: "/tmp", autoWelcomeIfNeeded: false)
        AppDelegate.shared = app
        app.tabManager = manager
        controller.setActiveTabManager(manager)
        let windowID = app.registerMainWindowContextForTesting(tabManager: manager)
        defer {
            controller.setActiveTabManager(previousManager)
            app.unregisterMainWindowContextForTesting(windowId: windowID)
            manager.tabs.forEach { $0.teardownAllPanels() }
            AppDelegate.shared = previousApp
            if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
        }
        let workspace = try #require(manager.selectedWorkspace)
        workspace.configureRemoteConnection(WorkspaceRemoteConfiguration(
            destination: "bmux-macmini", port: nil, identityFile: nil, sshOptions: [],
            localProxyPort: nil, relayPort: 64007,
            relayID: String(repeating: "a", count: 16), relayToken: String(repeating: "b", count: 64),
            localSocketPath: "/tmp/bmux-debug-test.sock", terminalStartupCommand: startupCommand
        ), autoConnect: false)
        workspace.applyRemoteConnectionStateUpdate(state, detail: "Fixture connection", target: "bmux-macmini")
        try body(workspace, controller)
    }
}
