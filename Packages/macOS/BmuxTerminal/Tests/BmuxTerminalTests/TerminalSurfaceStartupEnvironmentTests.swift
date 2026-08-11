import Foundation
import Testing

@testable import BmuxTerminal

@Suite("Terminal surface startup environment")
struct TerminalSurfaceStartupEnvironmentTests {
    @Test func managedBmuxContextExportsLegacyCmuxAliases() {
        let workspaceId = UUID()
        let surfaceId = UUID()
        let socketPath = "/tmp/bmux-test.sock"
        var environment: [String: String] = [:]
        var protectedKeys: Set<String> = []

        TerminalSurface.applyManagedBmuxContextEnvironment(
            TerminalSurface.BmuxContextEnvironment(
                workspaceId: workspaceId,
                surfaceId: surfaceId,
                socketPath: socketPath
            ),
            to: &environment,
            protectedKeys: &protectedKeys
        )

        #expect(environment["BMUX_WORKSPACE_ID"] == workspaceId.uuidString)
        #expect(environment["BMUX_SURFACE_ID"] == surfaceId.uuidString)
        #expect(environment["BMUX_PANEL_ID"] == surfaceId.uuidString)
        #expect(environment["BMUX_TAB_ID"] == workspaceId.uuidString)
        #expect(environment["BMUX_SOCKET_PATH"] == socketPath)

        #expect(environment["CMUX_WORKSPACE_ID"] == workspaceId.uuidString)
        #expect(environment["CMUX_SURFACE_ID"] == surfaceId.uuidString)
        #expect(environment["CMUX_PANEL_ID"] == surfaceId.uuidString)
        #expect(environment["CMUX_TAB_ID"] == workspaceId.uuidString)
        #expect(environment["CMUX_SOCKET_PATH"] == socketPath)

        for key in [
            "BMUX_WORKSPACE_ID",
            "BMUX_SURFACE_ID",
            "BMUX_PANEL_ID",
            "BMUX_TAB_ID",
            "BMUX_SOCKET_PATH",
            "CMUX_WORKSPACE_ID",
            "CMUX_SURFACE_ID",
            "CMUX_PANEL_ID",
            "CMUX_TAB_ID",
            "CMUX_SOCKET_PATH",
        ] {
            #expect(protectedKeys.contains(key))
        }
    }
}
