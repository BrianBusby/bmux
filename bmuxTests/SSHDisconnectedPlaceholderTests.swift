import BmuxCore
import BmuxFoundation
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct SSHDisconnectedPlaceholderTests {
    @Test func acceptedReconnectDoesNotExecuteASecondLocalStartupCommand() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ssh-placeholder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let duplicate = root.appendingPathComponent("duplicate-start")
        let cli = root.appendingPathComponent("bmux")
        let calls = root.appendingPathComponent("calls")
        let input = root.appendingPathComponent("input")
        let output = root.appendingPathComponent("output")
        let errors = root.appendingPathComponent("errors")
        try "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$BMUX_TEST_CALLS\"\nexit 0\n"
            .write(to: cli, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cli.path)
        try "\n".write(to: input, atomically: true, encoding: .utf8)
        let (script, workspaceID, surfaceID) = try await makePlaceholder(duplicateMarker: duplicate)
        defer { try? FileManager.default.removeItem(atPath: script) }
        var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("BMUX_") }
        environment["BMUX_BUNDLED_CLI_PATH"] = cli.path
        environment["BMUX_SOCKET_PATH"] = root.appendingPathComponent("owned.sock").path
        environment["BMUX_WORKSPACE_ID"] = workspaceID.uuidString
        environment["BMUX_SURFACE_ID"] = surfaceID.uuidString
        environment["BMUX_TEST_CALLS"] = calls.path
        // Owned files avoid blocking cooperative-executor pipe drains; payload assertions use exact captured bytes.
        let result = await CommandRunner(environment: environment).run(directory: root.path,
            executable: "/bin/sh", arguments: ["-c", "exec /bin/sh \"$1\" <\"$2\" >\"$3\" 2>\"$4\"",
                "placeholder", script, input.path, output.path, errors.path], timeout: 5)
        let stderr = try String(contentsOf: errors, encoding: .utf8)
        _ = try String(contentsOf: output, encoding: .utf8)
        #expect(result.executionError == nil)
        #expect(!result.timedOut)
        #expect(result.exitStatus == 0, Comment(rawValue: stderr))
        let recorded = try String(contentsOf: calls, encoding: .utf8).split(separator: "\n")
        #expect(recorded.count == 1)
        #expect(recorded.first?.contains("rpc workspace.remote.reconnect {\"workspace_id\":\"\(workspaceID.uuidString)\",\"surface_id\":\"\(surfaceID.uuidString)\"}") == true)
        #expect(!FileManager.default.fileExists(atPath: duplicate.path), "the native owner already replaces the terminal; the old placeholder must not execute SSH again")
    }

    @MainActor
    private func makePlaceholder(duplicateMarker: URL) throws -> (String, UUID, UUID) {
        let workspace = Workspace()
        defer { workspace.teardownAllPanels() }
        let original = try #require(workspace.focusedTerminalPanel)
        let quotedMarker = "'" + duplicateMarker.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        workspace.configureRemoteConnection(WorkspaceRemoteConfiguration(
            destination: "bmux-macmini", port: nil, identityFile: nil, sshOptions: [],
            localProxyPort: nil, relayPort: 64007, relayID: String(repeating: "a", count: 16),
            relayToken: String(repeating: "b", count: 64), localSocketPath: "/tmp/bmux-debug-test.sock",
            terminalStartupCommand: "/usr/bin/touch \(quotedMarker)"
        ), autoConnect: false)
        // Keep a live sibling so ending this pane does not start transport cleanup.
        _ = try #require(workspace.newTerminalSplit(from: original.id, orientation: .horizontal, focus: false))
        workspace.markRemoteTerminalSessionEnded(surfaceId: original.id, relayPort: 64007)
        let placeholder = workspace.createReplacementTerminalPanel()
        #expect(workspace.remoteDisconnectPlaceholderPanelIds.contains(placeholder.id))
        return (try #require(placeholder.surface.initialCommand), workspace.id, placeholder.id)
    }
}
