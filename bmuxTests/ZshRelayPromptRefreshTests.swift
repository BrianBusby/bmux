import Darwin
import Foundation
import Testing

/// Observes both real precmd relay callbacks instead of accepting the first log write.
@Suite("Zsh relay prompt refresh")
struct ZshRelayPromptRefreshTests {
    @Test func relayPromptRefreshUsesRefreshReason() async throws {
        let files = FileManager.default
        let root = URL(fileURLWithPath: "/tmp/zsh-relay-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            // The main shell is joined. Detached stubs only write their inherited FIFO descriptor;
            // they never reopen fixture paths, and this does not claim to join their process exits.
            do { try files.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned Zsh relay fixture directory") }
        }
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        let zdotdir = root.appendingPathComponent("zdotdir", isDirectory: true)
        try files.createDirectory(at: bin, withIntermediateDirectories: false)
        try files.createDirectory(at: zdotdir, withIntermediateDirectories: false)
        let fifo = root.appendingPathComponent("callbacks")
        guard mkfifo(fifo.path, 0o600) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let cli = bin.appendingPathComponent("bmux")
        try """
        #!/bin/sh
        printf '%s\\n' "$*" >&9
        """.write(to: cli, atomically: true, encoding: .utf8)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        let path = "\(bin.path):/usr/bin:/bin:/usr/sbin:/sbin"
        try "export PATH=\"\(path)\"\n".write(
            to: zdotdir.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8
        )
        let integration = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/shell-integration")
        let command = """
        exec 9<>"$BMUX_TEST_RELAY_FIFO" || exit 72
        zmodload zsh/datetime || exit 73
        _BMUX_TTY_REPORTED=1
        _BMUX_PORTS_LAST_RUN=-999
        _bmux_precmd
        typeset -F _bmux_deadline=$(( EPOCHREALTIME + 1.0 ))
        repeat 2; do
          typeset -F _bmux_remaining=$(( _bmux_deadline - EPOCHREALTIME ))
          (( _bmux_remaining > 0 )) || exit 71
          IFS= read -r -t "$_bmux_remaining" -u 9 _bmux_reply || exit 71
          printf '%s\\n' "$_bmux_reply"
        done
        exec 9>&-
        """
        // One absolute second preserves the original 20 × 50 ms observation failure cap.
        // Both small writes fit in the inherited O_RDWR FIFO even if the parent is cancelled;
        // neither worker needs a reader to open or can perform a later fixture-path write.
        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: "/bin/zsh", arguments: ["-i", "-c", command],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path, "TMPDIR": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
                "XDG_CACHE_HOME": root.path, "TERM": "xterm-256color",
                "SHELL": "/bin/zsh", "USER": NSUserName(), "PATH": path,
                "ZDOTDIR": integration.path, "BMUX_ZSH_ZDOTDIR": zdotdir.path,
                "BMUX_SHELL_INTEGRATION": "1", "BMUX_SHELL_INTEGRATION_DIR": integration.path,
                "BMUX_SOCKET_PATH": "127.0.0.1:64011",
                "BMUX_WORKSPACE_ID": "11111111-1111-1111-1111-111111111111",
                "BMUX_TAB_ID": "22222222-2222-2222-2222-222222222222",
                "BMUX_PANEL_ID": "22222222-2222-2222-2222-222222222222",
                "BMUX_TEST_RELAY_FIFO": fifo.path,
            ]
        )
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(
            result.stdout.contains(#"rpc surface.ports_kick {"workspace_id":"11111111-1111-1111-1111-111111111111","reason":"refresh","surface_id":"22222222-2222-2222-2222-222222222222"}"#),
            Comment(rawValue: result.stdout)
        )
    }
}
