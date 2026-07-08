import Foundation
import BmuxFoundation

nonisolated enum SSHPTYAttachStartupCommandBuilder {
    struct ForegroundAuth {
        let destination: String
        let port: Int?
        let identityFile: String?
        let sshOptions: [String]
        let token: String
    }

    static func command(
        sessionID: String? = nil,
        foregroundAuth: ForegroundAuth? = nil,
        remoteCommand: String? = nil,
        requireExisting: Bool = true
    ) -> String {
        var lines = [
            "bmux_ssh_attach_cli=\"${BMUX_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$bmux_ssh_attach_cli\" ] || [ ! -x \"$bmux_ssh_attach_cli\" ]; then bmux_ssh_attach_cli=\"$(command -v bmux 2>/dev/null || true)\"; fi",
            "if [ -z \"$bmux_ssh_attach_cli\" ]; then printf '%s\\n' '[bmux] bundled CLI not found for SSH PTY attach.' >&2; exit 127; fi",
            "if [ -z \"${BMUX_SOCKET_PATH:-}\" ]; then printf '%s\\n' '[bmux] required configuration missing for SSH PTY attach.' >&2; exit 1; fi",
            "if [ -z \"${BMUX_WORKSPACE_ID:-}\" ]; then printf '%s\\n' '[bmux] required workspace context missing for SSH PTY attach.' >&2; exit 1; fi",
        ]
        if let sessionID = normalized(sessionID) {
            lines.append("bmux_ssh_attach_session_id=\(shellQuote(sessionID))")
        } else {
            lines += [
                "if [ -z \"${BMUX_SURFACE_ID:-}\" ]; then printf '%s\\n' '[bmux] required terminal context missing for SSH PTY attach.' >&2; exit 1; fi",
                "bmux_ssh_attach_session_id=\"ssh-$BMUX_WORKSPACE_ID-$BMUX_SURFACE_ID\"",
            ]
        }
        if let foregroundAuth {
            lines += foregroundAuthLines(foregroundAuth)
        }
        let requireExistingFlag = requireExisting ? " --require-existing" : ""
        let commandB64Flag = normalized(remoteCommand).map {
            " --command-b64 \(shellQuote(Data($0.utf8).base64EncodedString()))"
        } ?? ""
        let attachCommand = "\"$bmux_ssh_attach_cli\" --socket \"$BMUX_SOCKET_PATH\" ssh-pty-attach --wait\(requireExistingFlag) --workspace \"$BMUX_WORKSPACE_ID\" --session-id \"$bmux_ssh_attach_session_id\" --attachment-id \"${BMUX_SURFACE_ID:-}\"\(commandB64Flag)"
        lines += retryingAttachLines(command: attachCommand)
        return "/bin/sh -c \(shellQuote(lines.joined(separator: "\n")))"
    }

    static func restoredRemoteShellCommand(relayPort: Int) -> String {
        RemoteInteractiveShellBootstrapBuilder.script(
            remoteRelayPort: relayPort,
            shellFeatures: RemoteInteractiveShellBootstrapBuilder.shellFeatures(),
            bundledZshIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "bmux-zsh-integration.zsh"),
            bundledBashIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "bmux-bash-integration.bash"),
            bundledFishIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "fish/config.fish")
        )
    }

    private static func retryingAttachLines(command: String) -> [String] {
        [
            "bmux_ssh_attach_reconnect_limit=\"${BMUX_SSH_RECONNECT_LIMIT:-20}\"",
            "case \"$bmux_ssh_attach_reconnect_limit\" in ''|*[!0-9]*) bmux_ssh_attach_reconnect_limit=20 ;; esac",
            "bmux_ssh_attach_reconnect_delay=\"${BMUX_SSH_RECONNECT_DELAY_SECONDS:-2}\"",
            "case \"$bmux_ssh_attach_reconnect_delay\" in ''|*[!0-9]*) bmux_ssh_attach_reconnect_delay=2 ;; esac",
            "bmux_ssh_attach_retry=0",
            "while :; do",
            "  \(command)",
            "  bmux_ssh_attach_status=$?",
            "  case \"$bmux_ssh_attach_status\" in 254|255) ;; *) exit \"$bmux_ssh_attach_status\" ;; esac",
            "  if [ \"$bmux_ssh_attach_retry\" -ge \"$bmux_ssh_attach_reconnect_limit\" ]; then exit \"$bmux_ssh_attach_status\"; fi",
            "  bmux_ssh_attach_retry=$((bmux_ssh_attach_retry + 1))",
            "  if [ -t 2 ]; then printf '\\n\\033[33m[bmux] remote PTY bridge closed; reattaching (attempt %s/%s).\\033[0m\\n' \"$bmux_ssh_attach_retry\" \"$bmux_ssh_attach_reconnect_limit\" >&2 || true; fi",
            "  if [ \"$bmux_ssh_attach_reconnect_delay\" -gt 0 ]; then sleep \"$bmux_ssh_attach_reconnect_delay\"; fi",
            "done",
        ]
    }

    private static func foregroundAuthLines(_ auth: ForegroundAuth) -> [String] {
        let sshCommand = sshForegroundAuthCommand(auth)
        let quotedToken = shellQuote(auth.token)
        return [
            "\(sshCommand)",
            "bmux_ssh_auth_status=$?",
            "if [ \"$bmux_ssh_auth_status\" -ne 0 ]; then exit \"$bmux_ssh_auth_status\"; fi",
            "bmux_ssh_auth_token=\(quotedToken)",
            "bmux_ssh_auth_payload=\"{\\\"workspace_id\\\":\\\"$BMUX_WORKSPACE_ID\\\",\\\"foreground_auth_token\\\":\\\"$bmux_ssh_auth_token\\\"}\"",
            "\"$bmux_ssh_attach_cli\" --socket \"$BMUX_SOCKET_PATH\" rpc workspace.remote.foreground_auth_ready \"$bmux_ssh_auth_payload\" >/dev/null 2>&1 || true",
            "unset bmux_ssh_auth_payload bmux_ssh_auth_status bmux_ssh_auth_token",
        ]
    }

    private static func sshForegroundAuthCommand(_ auth: ForegroundAuth) -> String {
        var arguments = ["ssh"]
        let options = sshOptionsWithRestoreControlDefaults(auth.sshOptions)
        if !hasSSHOptionKey(options, key: "ConnectTimeout") {
            arguments += ["-o", "ConnectTimeout=6"]
        }
        if !hasSSHOptionKey(options, key: "ServerAliveInterval") {
            arguments += ["-o", "ServerAliveInterval=20"]
        }
        if !hasSSHOptionKey(options, key: "ServerAliveCountMax") {
            arguments += ["-o", "ServerAliveCountMax=2"]
        }
        if let port = auth.port {
            arguments += ["-p", String(port)]
        }
        if let identityFile = normalized(auth.identityFile) {
            arguments += ["-i", identityFile]
        }
        for option in options {
            arguments += ["-o", option]
        }
        // The command-line `true` below conflicts with a host-configured
        // RemoteCommand unless overridden (issue #7246).
        arguments += SSHHostConfiguredRemoteCommand().overrideArguments
        arguments += ["-T", auth.destination, "true"]
        return arguments.map(shellQuote).joined(separator: " ")
    }

    static func sshOptionsWithRestoreControlDefaults(_ options: [String], relayPort: Int? = nil) -> [String] {
        var merged = options.compactMap(normalized)
        let controlMaster = sshOptionValue(named: "ControlMaster", in: merged)
        let controlMasterDisabled = sshOptionValueIsDisabled(controlMaster)
        if controlMaster == nil {
            merged.append("ControlMaster=auto")
        }
        if !controlMasterDisabled {
            if !hasSSHOptionKey(merged, key: "ControlPersist") {
                merged.append("ControlPersist=600")
            }
            if !hasSSHOptionKey(merged, key: "ControlPath") {
                merged.append("ControlPath=\(restoreControlPathTemplate(relayPort: relayPort))")
            }
        }
        return merged
    }

    private static func restoreControlPathTemplate(relayPort: Int?) -> String {
        if let relayPort, relayPort > 0 {
            return "/tmp/bmux-ssh-\(getuid())-\(relayPort)-%C"
        }
        return "/tmp/bmux-ssh-\(getuid())-%C"
    }

    static func sshOptionsSupportReusableForegroundAuth(_ options: [String]) -> Bool {
        guard !hasSSHOptionKey(options, key: "LocalCommand"),
              !hasSSHOptionKey(options, key: "PermitLocalCommand") else {
            return false
        }

        guard let controlPath = sshOptionValue(named: "ControlPath", in: options),
              !controlPath.isEmpty,
              controlPath.lowercased() != "none" else {
            return false
        }

        if sshOptionValueIsDisabled(sshOptionValue(named: "ControlMaster", in: options)) {
            return false
        }

        return !sshOptionValueIsDisabled(
            sshOptionValue(named: "ControlPersist", in: options),
            zeroIsDisabled: false
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func hasSSHOptionKey(_ options: [String], key: String) -> Bool {
        SSHAgentSocketResolver().hasOptionKey(options, key: key)
    }

    private static func sshOptionValue(named name: String, in options: [String]) -> String? {
        SSHAgentSocketResolver().optionValue(named: name, in: options)
    }

    private static func sshOptionValueIsDisabled(_ rawValue: String?, zeroIsDisabled: Bool = true) -> Bool {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["no", "false", "off"].contains(normalized) || (zeroIsDisabled && normalized == "0")
    }

    private static func shellQuote(_ value: String) -> String {
        let safePattern = "^[A-Za-z0-9_@%+=:,./-]+$"
        if value.range(of: safePattern, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
