import Foundation

extension Workspace {
    /// Writes a small shell wrapper that keeps a disconnected remote terminal visible.
    /// Returned path goes to `initialCommand`, which Ghostty runs as the PTY command.
    static func remoteDisconnectPlaceholderScript(target: String, reconnectCommand: String?) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent(
            "bmux-remote-disconnect-\(UUID().uuidString.lowercased()).sh"
        )
        // Encode the target as base64 and decode it inside the shell. This sidesteps every
        // layer of shell quoting: no matter what the target contains (`$(id)`, backticks,
        // single/double quotes, escape sequences), the shell never sees it as shell syntax.
        // Previous version only escaped backslash and double-quote, which left command
        // substitution and backticks as a live injection vector (Codex P2).
        let encodedTarget = Data(target.utf8).base64EncodedString()
        // Localized banner strings. Both use %s (not %@) because they're rendered by the
        // POSIX printf inside the shell wrapper, not by Swift's String(format:).
        let endedLineFormat = String(
            localized: "remote.disconnectBanner.sessionEnded",
            defaultValue: "[bmux] remote session disconnected: %s"
        )
        let reconnectLine = String(
            localized: "remote.disconnectBanner.reconnectHint",
            defaultValue: "[bmux] Press Enter to reconnect. This terminal will stay disconnected until then."
        )
        let reconnectUnavailableLine = String(
            localized: "remote.disconnectBanner.reconnectUnavailableHint",
            defaultValue: "[bmux] Reconnect this workspace from the sidebar or by running the original bmux remote command again."
        )
        // Encode the localized lines the same way as the target, so a translator using
        // backticks or $(…) in a translation string can't unexpectedly execute in the
        // user's local shell. Decoded inline at wrapper startup, then fed to printf.
        let encodedEndedFormat = Data(endedLineFormat.utf8).base64EncodedString()
        let encodedReconnectLine = Data(reconnectLine.utf8).base64EncodedString()
        let encodedReconnectUnavailableLine = Data(reconnectUnavailableLine.utf8).base64EncodedString()
        let encodedReconnectCommand = Data((reconnectCommand ?? "").utf8).base64EncodedString()
        let body = """
        #!/bin/sh
        bmux_disconnect_decode() {
          printf '%s' "$1" | base64 --decode 2>/dev/null || printf '%s' "$1" | base64 -D 2>/dev/null
        }
        bmux_disconnect_target="$(bmux_disconnect_decode '\(encodedTarget)')"
        bmux_disconnect_ended_format="$(bmux_disconnect_decode '\(encodedEndedFormat)')"
        bmux_disconnect_reconnect_line="$(bmux_disconnect_decode '\(encodedReconnectLine)')"
        bmux_disconnect_reconnect_unavailable_line="$(bmux_disconnect_decode '\(encodedReconnectUnavailableLine)')"
        bmux_disconnect_reconnect_command="$(bmux_disconnect_decode '\(encodedReconnectCommand)')"
        # Append newline + color codes ourselves rather than trusting the translator to
        # preserve them in every locale.
        printf '\\033[1;33m'
        printf "$bmux_disconnect_ended_format" "$bmux_disconnect_target"
        printf '\\033[0m\\n' >&2
        # Remove ourselves so /tmp doesn't accumulate these wrappers across sessions.
        rm -f -- "$0" 2>/dev/null || true
        if [ -n "$bmux_disconnect_reconnect_command" ]; then
          printf '\\033[2m%s\\033[0m\\n\\n' "$bmux_disconnect_reconnect_line" >&2
          IFS= read -r _ || exit 0
          bmux_reconnect_cli="${BMUX_BUNDLED_CLI_PATH:-}"
          if [ -z "$bmux_reconnect_cli" ] || [ ! -x "$bmux_reconnect_cli" ]; then
            bmux_reconnect_cli="$(command -v bmux 2>/dev/null || true)"
          fi
          bmux_reconnect_socket="${BMUX_SOCKET_PATH:-${BMUX_SOCKET:-}}"
          if [ -n "$bmux_reconnect_cli" ] && [ -n "$bmux_reconnect_socket" ] && [ -n "${BMUX_WORKSPACE_ID:-}" ] && [ -n "${BMUX_SURFACE_ID:-}" ]; then
            bmux_reconnect_payload="{\\"workspace_id\\":\\"$BMUX_WORKSPACE_ID\\""
            if [ -n "${BMUX_SURFACE_ID:-}" ]; then
              bmux_reconnect_payload="$bmux_reconnect_payload,\\"surface_id\\":\\"$BMUX_SURFACE_ID\\""
            fi
            bmux_reconnect_payload="$bmux_reconnect_payload}"
            if "$bmux_reconnect_cli" --socket "$bmux_reconnect_socket" rpc workspace.remote.reconnect "$bmux_reconnect_payload" >/dev/null 2>&1; then
              exit 0
            fi
          fi
          printf '\\033[2m%s\\033[0m\\n' "$bmux_disconnect_reconnect_unavailable_line" >&2
          while IFS= read -r _; do :; done
          exit 0
        fi
        printf '\\033[2m%s\\033[0m\\n' "$bmux_disconnect_reconnect_unavailable_line" >&2
        while IFS= read -r _; do :; done
        exit 0

        """
        do {
            try body.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL.path
        } catch {
            return "/bin/sh"
        }
    }
}
