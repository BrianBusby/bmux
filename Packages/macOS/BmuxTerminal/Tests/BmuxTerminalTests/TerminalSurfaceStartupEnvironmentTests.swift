import Foundation
import Testing

@testable import BmuxTerminal

@Suite("Terminal surface startup environment")
struct TerminalSurfaceStartupEnvironmentTests {
    @Test func managedBmuxContextExportsLegacyCmuxAliases() {
        let workspaceId = UUID()
        let stableWorkspaceId = UUID()
        let surfaceId = UUID()
        let socketPath = "/tmp/bmux-test.sock"
        var environment: [String: String] = [:]
        var protectedKeys: Set<String> = []

        TerminalSurface.applyManagedBmuxContextEnvironment(
            TerminalSurface.BmuxContextEnvironment(
                workspaceId: workspaceId,
                stableWorkspaceId: stableWorkspaceId,
                surfaceId: surfaceId,
                socketPath: socketPath
            ),
            to: &environment,
            protectedKeys: &protectedKeys
        )

        #expect(environment["BMUX_WORKSPACE_ID"] == workspaceId.uuidString)
        #expect(environment["BMUX_STABLE_WORKSPACE_ID"] == stableWorkspaceId.uuidString)
        #expect(environment["BMUX_SURFACE_ID"] == surfaceId.uuidString)
        #expect(environment["BMUX_PANEL_ID"] == surfaceId.uuidString)
        #expect(environment["BMUX_TAB_ID"] == workspaceId.uuidString)
        #expect(environment["BMUX_STABLE_TAB_ID"] == stableWorkspaceId.uuidString)
        #expect(environment["BMUX_SOCKET_PATH"] == socketPath)

        #expect(environment["CMUX_WORKSPACE_ID"] == workspaceId.uuidString)
        #expect(environment["CMUX_STABLE_WORKSPACE_ID"] == stableWorkspaceId.uuidString)
        #expect(environment["CMUX_SURFACE_ID"] == surfaceId.uuidString)
        #expect(environment["CMUX_PANEL_ID"] == surfaceId.uuidString)
        #expect(environment["CMUX_TAB_ID"] == workspaceId.uuidString)
        #expect(environment["CMUX_STABLE_TAB_ID"] == stableWorkspaceId.uuidString)
        #expect(environment["CMUX_SOCKET_PATH"] == socketPath)

        for key in [
            "BMUX_WORKSPACE_ID",
            "BMUX_STABLE_WORKSPACE_ID",
            "BMUX_SURFACE_ID",
            "BMUX_PANEL_ID",
            "BMUX_TAB_ID",
            "BMUX_STABLE_TAB_ID",
            "BMUX_SOCKET_PATH",
            "CMUX_WORKSPACE_ID",
            "CMUX_STABLE_WORKSPACE_ID",
            "CMUX_SURFACE_ID",
            "CMUX_PANEL_ID",
            "CMUX_TAB_ID",
            "CMUX_STABLE_TAB_ID",
            "CMUX_SOCKET_PATH",
        ] {
            #expect(protectedKeys.contains(key))
        }
    }

    @Test func managedAgentScopedResetPreventsStaleCodexIdentityLeak() {
        var environment = [
            "BMUX_AGENT_LAUNCH_KIND": "codex",
            "BMUX_CODEX_HOOK_BMUX_BIN": "/tmp/old-bmux",
            "BMUX_CODEX_PID": "123",
            "BMUX_DEBUG_LOG": "/tmp/old.log",
            "BMUX_TAG": "old-tag",
            "CODEX_SESSION_ID": "old-session",
            "CODEX_THREAD_ID": "old-thread"
        ]
        var protectedKeys: Set<String> = []

        TerminalSurface.applyManagedAgentScopedEnvironmentReset(
            to: &environment,
            protectedKeys: &protectedKeys
        )

        for key in [
            "BMUX_AGENT_LAUNCH_KIND",
            "BMUX_CODEX_HOOK_BMUX_BIN",
            "BMUX_CODEX_PID",
            "BMUX_DEBUG_LOG",
            "BMUX_TAG",
            "CODEX_SESSION_ID",
            "CODEX_THREAD_ID"
        ] {
            #expect(environment[key] == "")
            #expect(protectedKeys.contains(key))
        }

        let merged = TerminalSurface.mergedStartupEnvironment(
            base: environment,
            protectedKeys: protectedKeys,
            additionalEnvironment: ["CODEX_SESSION_ID": "workspace-session"],
            initialEnvironmentOverrides: ["BMUX_CODEX_PID": "456"]
        )

        #expect(merged["CODEX_SESSION_ID"] == "")
        #expect(merged["BMUX_CODEX_PID"] == "")
    }
}
