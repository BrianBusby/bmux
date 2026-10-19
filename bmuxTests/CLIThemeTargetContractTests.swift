import Foundation
import Testing

@MainActor
final class CLIThemeTargetContractTests {
    @Test func taggedSocketOverridesStaleBundleEnvironment() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-theme-target-\(UUID().uuidString)", isDirectory: true)
        let resources = root.appendingPathComponent("resources", isDirectory: true)
        let themes = resources.appendingPathComponent("themes", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned theme target directory") }
        }
        try FileManager.default.createDirectory(at: themes, withIntermediateDirectories: true)
        try "background = #101010\n".write(to: themes.appendingPathComponent("Theme A"), atomically: true, encoding: .utf8)
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let socketPath = "/tmp/bmux-debug-active-theme-\(suffix).sock"
        let staleBundle = "com.bmuxterm.app.debug.stale.theme"
        // The owned hexadecimal suffix needs no production slug-normalizer in the oracle.
        let targetBundle = "com.bmuxterm.app.debug.active.theme.\(suffix)"
        let observation = ThemeReloadObservation(bundleIdentifier: targetBundle)
        defer { observation.close() }
        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: cliPath,
            arguments: ["--json", "themes", "set", "Theme A"],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
                "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
                "BMUX_SOCKET_PASSWORD": "owned-theme-fixture",
                "GHOSTTY_RESOURCES_DIR": resources.path,
                "BMUX_SOCKET_PATH": socketPath, "BMUX_BUNDLE_ID": staleBundle,
                "BMUX_CLI_SENTRY_DISABLED": "1",
            ]
        )
        // The process and subsequent notification retain their separate original five-second bounds.
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        try await observation.wait(deadline: .seconds(5))
        #expect(observation.reloads.map(\.bundleIdentifier) == [targetBundle])
        #expect(observation.reloads.map(\.phase) == ["final"])
        #expect(observation.reloads.map(\.socketPath) == [socketPath])
        #expect(!result.stdout.contains(staleBundle))
        #expect(result.stdout.contains(targetBundle))
        let json = try #require(JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
        #expect(json["reload_target_bundle_id"] as? String == targetBundle)
        #expect(json["reload_requested"] as? Bool == true)
        let configPath = try #require(json["config_path"] as? String)
        try #require(configPath.hasPrefix(root.path + "/"), "CLI configuration must remain under the owned home")
        #expect(try String(contentsOfFile: configPath, encoding: .utf8).contains("theme = light:Theme A,dark:Theme A"))
    }
}
