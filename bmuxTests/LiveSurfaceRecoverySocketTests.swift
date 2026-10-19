import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct LiveSurfaceRecoverySocketTests {
    @Test
    func tabManagerDependentCommandsRecoverLiveSurfaceContext() throws {
        let fixture = LiveSurfaceRecoveryWindowFixture()
        defer { fixture.close() }
        fixture.prepare()
        let app = fixture.app
        let manager = fixture.manager
        let window = fixture.window
        let windowId = fixture.windowId

        let workspace = try #require(manager.selectedWorkspace)
        let terminalPanel = try #require(workspace.focusedTerminalPanel)
        let surfaceId = terminalPanel.id
        #expect(GhosttyApp.terminalSurfaceRegistry.surface(id: surfaceId) === terminalPanel.surface)
        #expect(terminalPanel.surface.debugLastKnownWorkspaceId() == workspace.id)

        try assertWorkspaceListContains(try fixture.v2Result(method: "workspace.list"), workspaceId: workspace.id)
        let baselineTree = try fixture.v2Result(method: "system.tree")
        let baselineWindows = try #require(baselineTree["windows"] as? [[String: Any]])
        #expect(baselineWindows.contains { ($0["id"] as? String) == windowId.uuidString })

        // Recovered presentation routes require a genuinely presented window.
        window.orderBack(nil)
        try #require(window.isVisible)
        app.unregisterMainWindowContextForTesting(windowId: windowId)
        TerminalController.shared.setActiveTabManager(nil)

        let ping = try fixture.v2Result(method: "system.ping")
        #expect(ping["pong"] as? Bool == true)
        _ = try fixture.v2Result(method: "system.capabilities")

        let tree = try fixture.v2Result(method: "system.tree")
        let debugTerminals = try fixture.v2Result(method: "debug.terminals")
        let terminals = try #require(debugTerminals["terminals"] as? [[String: Any]])
        let originalTerminal = try #require(
            terminals.first { ($0["surface_id"] as? String) == surfaceId.uuidString }
        )
        #expect(originalTerminal["mapped"] as? Bool == true)
        #expect(originalTerminal["workspace_id"] as? String == workspace.id.uuidString)
        #expect(originalTerminal["last_known_workspace_id"] as? String == workspace.id.uuidString)

        let recoveredTreeWindows = try #require(tree["windows"] as? [[String: Any]])
        #expect(
            recoveredTreeWindows.contains { ($0["id"] as? String) == windowId.uuidString },
            "system.tree should not report an empty world while a live terminal surface is still associated with its workspace"
        )

        let currentWindow = try fixture.v2Result(method: "window.current")
        #expect(currentWindow["window_id"] as? String == windowId.uuidString)

        let currentWorkspace = try fixture.v2Result(method: "workspace.current")
        #expect(currentWorkspace["workspace_id"] as? String == workspace.id.uuidString)

        let workspaceList = try fixture.v2Result(method: "workspace.list")
        try assertWorkspaceListContains(workspaceList, workspaceId: workspace.id)

        let workspaceListBySurface = try fixture.v2Result(method: "workspace.list", params: ["surface_id": surfaceId.uuidString])
        try assertWorkspaceListContains(workspaceListBySurface, workspaceId: workspace.id)

        let surfaces = try fixture.v2Result(method: "surface.list", params: ["surface_id": surfaceId.uuidString])
        #expect(surfaces["workspace_id"] as? String == workspace.id.uuidString)

        let currentSurface = try fixture.v2Result(method: "surface.current", params: ["surface_id": surfaceId.uuidString])
        #expect(currentSurface["workspace_id"] as? String == workspace.id.uuidString)

        let panes = try fixture.v2Result(method: "pane.list", params: ["surface_id": surfaceId.uuidString])
        #expect(panes["workspace_id"] as? String == workspace.id.uuidString)

        let health = try fixture.v2Result(method: "surface.health", params: ["surface_id": surfaceId.uuidString])
        #expect(health["workspace_id"] as? String == workspace.id.uuidString)

        let split = try fixture.v2Result(
            method: "surface.split",
            params: [
                "surface_id": surfaceId.uuidString,
                "direction": "right",
                "focus": false
            ]
        )
        #expect(split["surface_id"] as? String != nil)
    }

    private func assertWorkspaceListContains(_ payload: [String: Any], workspaceId: UUID) throws {
        let workspaces = try #require(payload["workspaces"] as? [[String: Any]])
        #expect(
            workspaces.contains { ($0["id"] as? String) == workspaceId.uuidString },
            "workspace.list should include \(workspaceId.uuidString)"
        )
    }
}
