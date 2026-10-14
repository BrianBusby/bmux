import BmuxFoundation
import Foundation
import Testing

@Suite
final class CLITmuxLaunchIdentityTests {
    @Test
    func tmuxEnvironmentStampsLaunchSurfaceInsteadOfFocusedPane() async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        // A platform temporary directory plus this fixture's UUID can exceed sun_path.
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("tmux-launch-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned tmux launch files") }
        }
        let socket = root.appendingPathComponent("sock").path
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let focusedWorkspace = "11111111-1111-1111-1111-111111111111"
        let focusedSurface = "22222222-2222-2222-2222-222222222222"
        let launchWorkspace = "33333333-3333-3333-3333-333333333333"
        let launchSurface = "44444444-4444-4444-4444-444444444444"
        let launchTab = "55555555-5555-5555-5555-555555555555"
        let server = CLISocketFixture(path: socket) { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            let response: [String: Any]
            if method == "system.identify" {
                response = ["id": id, "ok": true, "result": ["focused": [
                    "workspace_id": focusedWorkspace, "surface_id": focusedSurface, "pane_id": "%1",
                ]]]
            } else {
                #expect(method == "pane.list")
                // Canonical pane lookup may fail; the focused identity remains valid.
                response = ["id": id, "ok": false, "error": ["code": "unsupported", "message": method]]
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
        let runner = CommandRunner(environment: [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "TMPDIR": root.path,
            "XDG_CONFIG_HOME": root.appendingPathComponent("config").path,
            "XDG_DATA_HOME": root.appendingPathComponent("data").path,
            "XDG_CACHE_HOME": root.appendingPathComponent("cache").path,
            "PATH": "/usr/bin:/bin", "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_WORKSPACE_ID": launchWorkspace,
            "BMUX_SURFACE_ID": launchSurface, "BMUX_PANEL_ID": launchSurface,
            "BMUX_TAB_ID": launchTab,
        ])
        let (result, commands) = try await server.capture {
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" __debug-tmux-compat-env </dev/null >\"$2\" 2>\"$3\"",
                "tmux-launch", cli, stdout.path, stderr.path,
            ], timeout: 30)
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errors)")
        let output = try String(contentsOf: stdout, encoding: .utf8)
        // Nil focused context also preserves inherited IDs, so require the real protocol path.
        let methods = try commands.map { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            return try #require(request["method"] as? String)
        }
        #expect(methods.filter { $0 == "system.identify" }.count == 1)
        #expect(output.contains("BMUX_SURFACE_ID=\(launchSurface)"), "\(output)\n\(errors)")
        #expect(!output.contains("BMUX_SURFACE_ID=\(focusedSurface)"), "\(output)")
        #expect(output.contains("BMUX_WORKSPACE_ID=\(launchWorkspace)"), "\(output)")
        #expect(output.contains("BMUX_PANEL_ID=\(launchSurface)"), "\(output)")
        #expect(output.contains("BMUX_TAB_ID=\(launchTab)"), "\(output)")
    }
}
