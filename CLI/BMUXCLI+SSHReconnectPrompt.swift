import Foundation

extension BMUXCLI {
    func sshAutoReconnectNoteFormat() -> String {
        let status = String(localized: "cli.ssh.autoReconnect.status", defaultValue: "[bmux] ssh exited with status %s; reconnecting (attempt %s/%s).")
        let stopHint = String(localized: "cli.ssh.autoReconnect.stopHint", defaultValue: "[bmux] close this pane or press Ctrl-C to stop reconnecting.")
        return "\\n\\033[33m\(status)\\033[0m\\n\\033[2m\(stopHint)\\033[0m\\n"
    }

    func sshManualReconnectExitPromptFormat() -> String {
        let status = String(localized: "cli.ssh.manualReconnectPrompt.status", defaultValue: "[bmux] ssh exited with status %s.")
        let detail = String(localized: "cli.ssh.manualReconnectPrompt.detail", defaultValue: "[bmux] the remote VM may have been paused, destroyed, or lost network.")
        let prompt = String(localized: "cli.ssh.manualReconnectPrompt.prompt", defaultValue: "[bmux] press Enter to close this pane. Press r then Enter to reconnect.")
        return "\\n\\033[31m\(status)\\033[0m\\n\\033[2m\(detail)\\033[0m\\n\\033[2m\(prompt)\\033[0m\\n"
    }

    func sshRemoteReconnectShellFunction() -> String {
        [
            "bmux_ssh_remote_reconnect() {",
            "  bmux_reconnect_cli=\"${BMUX_BUNDLED_CLI_PATH:-}\"",
            "  if [ -z \"$bmux_reconnect_cli\" ] || [ ! -x \"$bmux_reconnect_cli\" ]; then bmux_reconnect_cli=\"$(command -v bmux 2>/dev/null || true)\"; fi",
            "  bmux_reconnect_socket=\"${BMUX_SOCKET_PATH:-${BMUX_SOCKET:-}}\"",
            "  if [ -z \"$bmux_reconnect_cli\" ] || [ -z \"$bmux_reconnect_socket\" ] || [ -z \"${BMUX_WORKSPACE_ID:-}\" ]; then return 0; fi",
            "  bmux_reconnect_payload=\"{\\\"workspace_id\\\":\\\"$BMUX_WORKSPACE_ID\\\"\"",
            "  if [ -n \"${BMUX_SURFACE_ID:-}\" ]; then bmux_reconnect_payload=\"$bmux_reconnect_payload,\\\"surface_id\\\":\\\"$BMUX_SURFACE_ID\\\"\"; fi",
            "  bmux_reconnect_payload=\"$bmux_reconnect_payload}\"",
            "  \"$bmux_reconnect_cli\" --socket \"$bmux_reconnect_socket\" rpc workspace.remote.reconnect \"$bmux_reconnect_payload\" >/dev/null 2>&1",
            "}",
        ].joined(separator: "\n")
    }
}
