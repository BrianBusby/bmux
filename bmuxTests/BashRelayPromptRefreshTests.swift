import Darwin
import Foundation
import Testing

/// Exercises the real detached relay callback, waiting for refresh rather than any log entry.
@Suite("Bash relay prompt refresh")
struct BashRelayPromptRefreshTests {
    @Test func relayPromptRefreshUsesRefreshReasonWithoutPromptNoise() async throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: "/tmp/bash-relay-\(UUID().uuidString)", isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
        defer {
            // The process runner joins Bash; the original fast detached stubs remain untracked.
            do { try fileManager.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned Bash relay fixture directory") }
        }
        let log = root.appendingPathComponent("relay.log")
        let refresh = root.appendingPathComponent("refresh")
        guard mkfifo(refresh.path, 0o600) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let cli = bin.appendingPathComponent("bmux")
        try """
        #!/bin/sh
        printf '%s\\n' "$*" >> "$BMUX_TEST_RELAY_LOG" || exit 73
        if [ "$1" = rpc ] && [ "$2" = surface.ports_kick ]; then
          exec 9<>"$BMUX_TEST_REFRESH_FIFO" || exit 72
          printf '\\n' >&9
          exec 9>&-
        fi
        exit 0
        """.write(to: cli, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        let integration = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/shell-integration/bmux-bash-integration.bash")
        let rc = root.appendingPathComponent(".bashrc")
        try ". \"\(integration.path)\"\n".write(to: rc, atomically: true, encoding: .utf8)
        let command = """
        exec 9<>"$BMUX_TEST_REFRESH_FIFO" || exit 72
        : > "$BMUX_TEST_RELAY_LOG"
        _BMUX_TTY_REPORTED=1
        _BMUX_PORTS_LAST_RUN=-999
        _bmux_prompt_command
        IFS= read -r -t 1 -u 9 _bmux_refresh || { printf '%s\\n' 'Missing refresh completion' >&2; exit 71; }
        exec 9>&-
        cat "$BMUX_TEST_RELAY_LOG"
        """
        // O_RDWR makes the one-byte callback independent of reader admission, including parent exit.
        // The one-second read is the original observation failure bound, never a settling delay.
        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: "/bin/bash",
            arguments: ["--noprofile", "--rcfile", rc.path, "-i", "-c", command],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path, "TMPDIR": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
                "XDG_CACHE_HOME": root.path, "TERM": "xterm-256color",
                "SHELL": "/bin/bash", "USER": NSUserName(),
                "PATH": "\(bin.path):/usr/bin:/bin:/usr/sbin:/sbin",
                "BMUX_SOCKET_PATH": "127.0.0.1:64011",
                "BMUX_WORKSPACE_ID": "11111111-1111-1111-1111-111111111111",
                "BMUX_TAB_ID": "22222222-2222-2222-2222-222222222222",
                "BMUX_PANEL_ID": "22222222-2222-2222-2222-222222222222",
                "BMUX_TEST_RELAY_LOG": log.path, "BMUX_TEST_REFRESH_FIFO": refresh.path,
            ]
        )
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(!result.stderr.contains("_bmux_report_tmux_state"), Comment(rawValue: result.stderr))
        #expect(
            result.stdout.contains(#"rpc surface.ports_kick {"workspace_id":"11111111-1111-1111-1111-111111111111","reason":"refresh","surface_id":"22222222-2222-2222-2222-222222222222"}"#),
            Comment(rawValue: result.stdout)
        )
    }
}
