import Foundation
import Testing

@MainActor
final class CLIThemeWriteReloadTests {
    @Test func everyThemeWritePostsFinalReload() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("bmux-theme-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned theme reload directory") }
        }
        let resources = root.appendingPathComponent("resources", isDirectory: true)
        let themes = resources.appendingPathComponent("themes", isDirectory: true)
        try FileManager.default.createDirectory(at: themes, withIntermediateDirectories: true)
        for (name, background) in [("Theme A", "#101010"), ("Theme B", "#f8f8f8"), ("Theme C", "#003b49")] {
            try "background = \(background)\nforeground = #eeeeee\ncursor-color = #ff00ff\ncursor-text = #000000".write(to: themes.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let socketPath = root.appendingPathComponent("s.sock").path
        let bundleIdentifier = "com.bmuxterm.fixture.theme.\(UUID().uuidString.lowercased())"
        let configURL = root.appendingPathComponent("Library/Application Support/\(bundleIdentifier)/config.ghostty")
        let observation = ThemeReloadObservation(bundleIdentifier: bundleIdentifier)
        defer { observation.close() }
        let socket = CLISocketFixture(path: socketPath, response: { _ in "OK" })
        let captured = try await socket.capture { @Sendable in
            var values: [String] = []
            for themeName in ["Theme A", "Theme B", "Theme C"] {
                let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
                    executable: cliPath, arguments: ["themes", "set", themeName],
                    environment: [
                        "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                        "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
                        "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
                        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
                        "BMUX_SOCKET_PASSWORD": "owned-theme-reload-fixture",
                        "GHOSTTY_RESOURCES_DIR": resources.path,
                        "BMUX_SOCKET_PATH": socketPath, "BMUX_BUNDLE_ID": bundleIdentifier,
                        "BMUX_CLI_SENTRY_DISABLED": "1",
                    ]
                )
                // Each throwing, joined run retains its original local and CI five-second bound.
                #expect(result.status == 0, Comment(rawValue: result.stdout + result.stderr))
                values.append(try Self.managedThemeValue(in: configURL))
            }
            return values
        }
        // BMUXTestExpectation.wait(timeout:) applies five seconds separately to each event.
        for _ in 0..<3 { try await observation.wait(deadline: .seconds(5)) }
        #expect(captured.result == [
            "light:Theme A,dark:Theme A", "light:Theme B,dark:Theme B", "light:Theme C,dark:Theme C",
        ])
        #expect(observation.reloads.map(\.bundleIdentifier) == Array(repeating: bundleIdentifier, count: 3))
        #expect(observation.reloads.map(\.phase) == Array(repeating: "final", count: 3))
        #expect(captured.commands.isEmpty)
    }

    private nonisolated static func managedThemeValue(in configURL: URL) throws -> String {
        let contents = try String(contentsOf: configURL, encoding: .utf8)
        let values = contents.components(separatedBy: .newlines).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == "theme" else {
                return nil
            }
            return parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return try #require(values.last)
    }
}
