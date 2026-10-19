import Foundation
import Testing

/// Owns authentication, one-way feed observation, and joined process/socket cleanup.
final class FeedHookNoResponseFixture: Sendable {
    let root: URL
    let cli: String

    init(cli: String) throws {
        self.cli = cli
        root = URL(fileURLWithPath: "/tmp/feed-hook-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned feed hook fixture directory") }
    }

    func run(source: String, event: String, tool: String, pidKey: String) async throws -> (
        output: ShellContractProcess.Result, observed: Bool, feeds: [String]
    ) {
        let socket = root.appendingPathComponent("sock").path
        let input = root.appendingPathComponent("input")
        let password = UUID().uuidString
        let workspace = "33333333-3333-3333-3333-333333333333"
        let surface = "44444444-4444-4444-4444-444444444444"
        let payload: [String: Any] = [
            "hook_event_name": event, "session_id": "\(source)-session-123",
            "cwd": root.path, "tool_name": tool,
            "tool_input": ["path": root.appendingPathComponent("README.md").path],
        ]
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
            "XDG_CACHE_HOME": root.path, "TMPDIR": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_WORKSPACE_ID": workspace,
            "BMUX_SURFACE_ID": surface, "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
        environment[pidKey] = "626262"
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        let server = CLISocketFixture(path: socket) { line in
            if line.hasPrefix("auth ") {
                // Explicit owned credentials prevent fallback to the user's password/keychain.
                guard line == "auth \(password)" else {
                    throw NSError(domain: "FeedHookAuthenticationMismatch", code: 1)
                }
                return "OK"
            }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            #expect(request["method"] as? String == "feed.push")
            #expect(request["id"] == nil)
            let parameters = try #require(request["params"] as? [String: Any])
            #expect(parameters["wait_timeout_seconds"] as? Int == 0)
            let feed = try #require(parameters["event"] as? [String: Any])
            #expect(feed["_source"] as? String == source)
            #expect(feed["_ppid"] as? Int == 626262)
            #expect(feed["workspace_id"] as? String == workspace)
            signal.yield(())
            return nil // Authentication replies never stand in for a feed response.
        }
        let runner = ShellContractProcess(root: root, deadline: .seconds(3))
        let (outcome, commands) = try await server.capture {
            // Retain producer errors until the final queued input and socket cleanup join.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await runner.run(
                    executable: "/bin/sh", arguments: [
                        "-c", "exec \"$1\" --socket \"$2\" --password \"$3\" hooks feed --source \"$4\" --event \"$5\" <\"$6\"",
                        "feed-hook", cli, socket, password, source, event, input.path,
                    ], environment: environment
                ))
            } catch { return .failure(error) }
        }
        #expect(!FileManager.default.fileExists(atPath: socket))
        let authenticationCount = commands.filter { $0.hasPrefix("auth ") }.count
        let feeds = commands.filter { !$0.hasPrefix("auth ") }
        let output: ShellContractProcess.Result
        do { output = try outcome.get() }
        catch {
            Issue.record(error, "\(source) failed after \(authenticationCount) authentication and \(feeds.count) feed requests")
            throw error
        }
        #expect(authenticationCount == 1)
        return (output, try await observe(events, timeout: .seconds(5)), feeds)
    }

    private func observe(_ events: AsyncStream<Void>, timeout: Duration) async throws -> Bool {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return true }
                return false
            }
            group.addTask {
                // Original five-second server failure bound, never a settling delay.
                try await ContinuousClock().sleep(for: timeout)
                return false
            }
            return try await group.next() ?? false
        }
    }
}
