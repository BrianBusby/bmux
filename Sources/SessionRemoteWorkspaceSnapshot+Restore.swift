import Foundation
import BmuxCore
#if canImport(Security)
import Security
#endif

extension SessionRemoteWorkspaceSnapshot {
    func workspaceConfiguration(
        localSocketPath: String? = nil,
        allowPersistentPTYRestore: Bool = true,
        preserveSSHOptions: Bool = false,
        agentSocketPath overrideAgentSocketPath: String? = nil
    ) -> WorkspaceRemoteConfiguration? {
        let normalizedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDestination.isEmpty else { return nil }
        let normalizedManagedCloudVMID = WorkspaceRemoteConfiguration.normalizedOptionalValue(managedCloudVMID)
        if transport == .websocket {
            guard let normalizedManagedCloudVMID else { return nil }
            return WorkspaceRemoteConfiguration(
                transport: .websocket,
                destination: normalizedDestination,
                port: nil,
                identityFile: nil,
                sshOptions: [],
                localProxyPort: nil,
                relayPort: nil,
                relayID: nil,
                relayToken: nil,
                localSocketPath: WorkspaceRemoteConfiguration.normalizedOptionalValue(localSocketPath),
                managedCloudVMID: normalizedManagedCloudVMID,
                terminalStartupCommand: Self.defaultFreestyleSSHAttachCommand(vmID: normalizedManagedCloudVMID),
                agentSocketPath: nil,
                daemonWebSocketEndpoint: nil,
                preserveAfterTerminalExit: true,
                persistentDaemonSlot: Self.defaultFreestylePersistentDaemonSlot,
                skipDaemonBootstrap: true
            )
        }
        guard transport == .ssh else { return nil }
        let normalizedPort = port.flatMap { port in
            (1...65535).contains(port) ? port : nil
        }

        let normalizedPersistentDaemonSlot = WorkspaceRemoteConfiguration.normalizedPersistentDaemonSlot(persistentDaemonSlot)
        let normalizedLocalSocketPath = WorkspaceRemoteConfiguration.normalizedOptionalValue(localSocketPath)
        let normalizedRelayPort = relayPort.flatMap { port in
            (1...65535).contains(port) ? port : nil
        }
        let preservedOptions = preserveSSHOptions
            ? WorkspaceRemoteConfiguration.trimmedSSHOptions(sshOptions)
            : Self.normalizedSSHOptions(sshOptions)
        let optionsWithRestoreControlDefaults = SSHPTYAttachStartupCommandBuilder.sshOptionsWithRestoreControlDefaults(
            preservedOptions,
            relayPort: normalizedRelayPort
        )
        let fallbackSSHOptions = preserveSSHOptions
            ? Self.normalizedSSHOptions(preservedOptions)
            : preservedOptions
        let managedCloudVMID = normalizedManagedCloudVMID
            ?? Self.legacyDefaultFreestyleVMID(destination: normalizedDestination, skipDaemonBootstrap: skipDaemonBootstrap)
        let defaultFreestyleVMID = skipDaemonBootstrap == true ? managedCloudVMID : nil
        let effectivePersistentDaemonSlot = normalizedPersistentDaemonSlot
            ?? (defaultFreestyleVMID == nil ? nil : Self.defaultFreestylePersistentDaemonSlot)
        let preservePTYSession =
            allowPersistentPTYRestore &&
            preserveAfterTerminalExit == true &&
            skipDaemonBootstrap != true &&
            effectivePersistentDaemonSlot != nil &&
            normalizedLocalSocketPath != nil &&
            normalizedRelayPort != nil &&
            SSHPTYAttachStartupCommandBuilder.sshOptionsSupportReusableForegroundAuth(optionsWithRestoreControlDefaults)
        let restoreDefaultFreestyleSSHD = defaultFreestyleVMID != nil
        let restoredSSHOptions = preservePTYSession ? optionsWithRestoreControlDefaults : fallbackSSHOptions
        let foregroundAuthToken = preservePTYSession ? UUID().uuidString.lowercased() : nil
        let foregroundAuth = foregroundAuthToken.map {
            SSHPTYAttachStartupCommandBuilder.ForegroundAuth(
                destination: normalizedDestination,
                port: normalizedPort,
                identityFile: Self.normalizedIdentityPath(identityFile),
                sshOptions: restoredSSHOptions,
                token: $0
            )
        }
        let restoredRelayID = preservePTYSession
            ? UUID().uuidString.lowercased()
            : nil
        let restoredRelayToken = preservePTYSession
            ? Self.restoreRelayTokenHex()
            : nil
        let restoredRemoteShellCommand = preservePTYSession
            ? normalizedRelayPort.map(SSHPTYAttachStartupCommandBuilder.restoredRemoteShellCommand(relayPort:))
            : nil
        return WorkspaceRemoteConfiguration(
            transport: transport,
            destination: normalizedDestination,
            port: normalizedPort,
            identityFile: Self.normalizedIdentityPath(identityFile),
            sshOptions: restoredSSHOptions,
            localProxyPort: nil,
            relayPort: preservePTYSession ? normalizedRelayPort : nil,
            relayID: restoredRelayID,
            relayToken: restoredRelayToken,
            localSocketPath: preservePTYSession ? normalizedLocalSocketPath : nil,
            managedCloudVMID: managedCloudVMID,
            terminalStartupCommand: {
                if preservePTYSession {
                    return SSHPTYAttachStartupCommandBuilder.command(
                        foregroundAuth: foregroundAuth,
                        remoteCommand: restoredRemoteShellCommand,
                        // Restored panels get explicit require-existing attach commands with their
                        // persisted session IDs; this workspace default is for new panes.
                        requireExisting: false
                    )
                }
                if let defaultFreestyleVMID {
                    return Self.defaultFreestyleSSHAttachCommand(vmID: defaultFreestyleVMID)
                }
                return sshReconnectCommand(
                    destination: normalizedDestination,
                    port: normalizedPort,
                    sshOptions: restoredSSHOptions
                )
            }(),
            foregroundAuthToken: foregroundAuthToken,
            agentSocketPath: WorkspaceRemoteConfiguration.resolvedAgentSocketPath(
                sshOptions: restoredSSHOptions,
                explicitAgentSocketPath: overrideAgentSocketPath
            ),
            daemonWebSocketEndpoint: nil,
            preserveAfterTerminalExit: preservePTYSession || restoreDefaultFreestyleSSHD,
            persistentDaemonSlot: (preservePTYSession || restoreDefaultFreestyleSSHD) ? effectivePersistentDaemonSlot : nil,
            skipDaemonBootstrap: skipDaemonBootstrap == true
        )
    }

    private static func restoreRelayTokenHex() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
#if canImport(Security)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
#endif
        return (UUID().uuidString + UUID().uuidString)
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    private func sshReconnectCommand(
        destination normalizedDestination: String,
        port normalizedPort: Int?,
        sshOptions reconnectSSHOptions: [String]? = nil
    ) -> String? {
        var arguments = ["ssh"]
        if let normalizedPort {
            arguments += ["-p", String(normalizedPort)]
        }
        if let identityFile = Self.normalizedIdentityPath(identityFile) {
            arguments += ["-i", identityFile]
        }
        let normalizedOptions = reconnectSSHOptions ?? Self.normalizedSSHOptions(sshOptions)
        for option in normalizedOptions {
            arguments += ["-o", option]
        }
        if !Self.hasSSHOptionKey(normalizedOptions, key: "RequestTTY") {
            arguments.append("-tt")
        }
        arguments.append(normalizedDestination)
        return arguments.map(Self.shellQuote).joined(separator: " ")
    }

    private static func normalizedIdentityPath(_ value: String?) -> String? {
        WorkspaceRemoteConfiguration.normalizedIdentityPath(value)
    }

    private static func normalizedSSHOptions(_ options: [String]) -> [String] {
        WorkspaceRemoteConfiguration.durableSSHOptions(options)
    }

    private static func hasSSHOptionKey(_ options: [String], key: String) -> Bool {
        WorkspaceRemoteConfiguration.hasSSHOptionKey(options, key: key)
    }

    private static let defaultFreestylePersistentDaemonSlot = "bmux-default-freestyle-sshd-v1"

    private static func legacyDefaultFreestyleVMID(destination: String, skipDaemonBootstrap: Bool?) -> String? {
        guard skipDaemonBootstrap == true else { return nil }
        let pattern = #"^([A-Za-z0-9._-]+)\+bmux@vm-ssh\.freestyle\.sh$"#
        guard let match = destination.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let matched = String(destination[match])
        guard let plusRange = matched.range(of: "+bmux@vm-ssh.freestyle.sh") else {
            return nil
        }
        return String(matched[..<plusRange.lowerBound])
    }

    private static func defaultFreestyleSSHAttachCommand(vmID: String) -> String {
        let lines = [
            "bmux_freestyle_cli=\"${BMUX_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$bmux_freestyle_cli\" ] || [ ! -x \"$bmux_freestyle_cli\" ]; then bmux_freestyle_cli=\"$(command -v bmux 2>/dev/null || true)\"; fi",
            "if [ -z \"$bmux_freestyle_cli\" ]; then printf '%s\\n' '[bmux] bundled CLI not found for Cloud VM SSH attach.' >&2; exit 127; fi",
            "BMUX_SSH_RECONNECT_LIMIT=\"${BMUX_SSH_RECONNECT_LIMIT:-86400}\"",
            "BMUX_SSH_RECONNECT_DELAY_SECONDS=\"${BMUX_SSH_RECONNECT_DELAY_SECONDS:-2}\"",
            "BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT=\"${BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT:-$BMUX_SSH_RECONNECT_LIMIT}\"",
            "BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS=\"${BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS:-$BMUX_SSH_RECONNECT_DELAY_SECONDS}\"",
            "export BMUX_SSH_RECONNECT_LIMIT BMUX_SSH_RECONNECT_DELAY_SECONDS",
            "export BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS",
            "bmux_freestyle_attach() {",
            "  if [ -n \"${BMUX_SOCKET_PATH:-}\" ]; then",
            "    \"$bmux_freestyle_cli\" --socket \"$BMUX_SOCKET_PATH\" vm-pty-attach --id \(shellQuote(vmID)) --default-freestyle-sshd",
            "  else",
            "    \"$bmux_freestyle_cli\" vm-pty-attach --id \(shellQuote(vmID)) --default-freestyle-sshd",
            "  fi",
            "}",
            "bmux_freestyle_retry=0",
            "while :; do",
            "  if [ \"$bmux_freestyle_retry\" -gt 0 ]; then",
            "    export BMUX_CLOUD_RECONNECT_ATTEMPT=\"$bmux_freestyle_retry\"",
            "  else",
            "    unset BMUX_CLOUD_RECONNECT_ATTEMPT",
            "  fi",
            "  bmux_freestyle_attach",
            "  bmux_freestyle_status=$?",
            "  case \"$bmux_freestyle_status\" in 254|255) ;; *) exit \"$bmux_freestyle_status\" ;; esac",
            "  if [ \"$bmux_freestyle_retry\" -ge \"$BMUX_SSH_RECONNECT_LIMIT\" ]; then exit \"$bmux_freestyle_status\"; fi",
            "  bmux_freestyle_retry=$((bmux_freestyle_retry + 1))",
            "  sleep \"$BMUX_SSH_RECONNECT_DELAY_SECONDS\"",
            "done",
        ]
        return "/bin/sh -c \(shellQuote(lines.joined(separator: "\n")))"
    }

    private static func shellQuote(_ value: String) -> String {
        let safePattern = "^[A-Za-z0-9_@%+=:,./-]+$"
        if value.range(of: safePattern, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
