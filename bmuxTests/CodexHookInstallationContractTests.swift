import Foundation
import Testing

final class CodexHookInstallationContractTests {
    @Test
    func prefersLaunchingAppBundledCLIAndCollapsesDuplicatePromptEntries() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-hook-install-\(UUID().uuidString)", isDirectory: true)
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned Codex hook installation directory") }
        }

        let previousBundledHookCommand = "bmux_cli=\"${BMUX_BUNDLED_CLI_PATH:-}\"; if [ -z \"$bmux_cli\" ] || [ ! -x \"$bmux_cli\" ]; then bmux_cli=\"$(command -v bmux 2>/dev/null || true)\"; fi; [ -n \"$BMUX_SURFACE_ID\" ] && [ \"$BMUX_CODEX_HOOKS_DISABLED\" != \"1\" ] && [ -n \"$bmux_cli\" ] && \"$bmux_cli\" hooks codex prompt-submit || echo '{}'"
        let legacyHookJSON: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            [
                                "command": previousBundledHookCommand,
                                "timeout": 5000,
                                "type": "command",
                            ],
                        ],
                    ],
                    [
                        "hooks": [
                            [
                                "command": previousBundledHookCommand,
                                "timeout": 5000,
                                "type": "command",
                            ],
                        ],
                    ],
                ],
            ],
        ]
        try JSONSerialization.data(withJSONObject: legacyHookJSON, options: [.prettyPrinted, .sortedKeys])
            .write(to: codexHome.appendingPathComponent("hooks.json", isDirectory: false), options: .atomic)

        // Preserve the original five-second no-timeout boundary and join before cleanup.
        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: cliPath,
            arguments: ["hooks", "codex", "install", "--yes"],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
                "TMPDIR": root.path, "PWD": root.path, "BMUX_UI_TEST_MODE": "1",
                "CODEX_HOME": codexHome.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "BMUX_CLI_SENTRY_DISABLED": "1",
            ]
        )

        #expect(result.status == 0, "\(result.stderr)")

        let hookURL = codexHome.appendingPathComponent("hooks.json", isDirectory: false)
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: hookURL)) as? [String: Any])
        let hooks = try #require(json["hooks"] as? [String: Any])
        let allCommands = hooks.values
            .compactMap { $0 as? [[String: Any]] }
            .flatMap { $0 }
            .compactMap { $0["hooks"] as? [[String: Any]] }
            .flatMap { $0 }
            .compactMap { $0["command"] as? String }
        let commandBodies = try allCommands.map { command in
            try #require(command.hasPrefix(root.path + "/"), "Generated script must be owned")
            return try String(contentsOfFile: command, encoding: .utf8)
        }
        let groups = try #require(hooks["UserPromptSubmit"] as? [[String: Any]])
        let entries = try groups.flatMap { try #require($0["hooks"] as? [[String: Any]]) }
        // Count actual configured entries, not distinct bodies or inline substrings in paths.
        #expect(entries.count == 1, "Codex setup should collapse duplicate prompt entries")
        let promptCommand = try #require(entries.first?["command"] as? String)
        #expect(try String(contentsOfFile: promptCommand, encoding: .utf8).contains("hooks codex prompt-submit"))
        #expect(
            commandBodies.contains {
                $0.contains("BMUX_BUNDLED_CLI_PATH")
                    && $0.contains("\"$bmux_cli\" --socket \"$BMUX_SOCKET_PATH\" hooks codex prompt-submit")
            },
            "Codex hooks should route through the launching app's bundled CLI, saw \(commandBodies)"
        )
        #expect(
            !commandBodies.contains { $0.contains("command -v bmux >/dev/null 2>&1 && bmux hooks codex") },
            "Codex hooks must not use the reload-global bmux shim directly, saw \(commandBodies)"
        )
        #expect(
            !commandBodies.contains { $0 == previousBundledHookCommand },
            "Codex setup should replace bundled-CLI hooks that did not pin BMUX_SOCKET_PATH, saw \(commandBodies)"
        )
    }
}
