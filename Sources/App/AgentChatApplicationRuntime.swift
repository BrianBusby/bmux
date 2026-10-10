import BmuxAgentChat
import BmuxSettings
import Foundation

/// Executable composition for transcript observation and opt-in shared hosts.
@MainActor
final class AgentChatApplicationRuntime {
    let transcript = AgentChatTranscriptService()
    lazy var terminal: TerminalChatRuntime = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // The shared host and its TUI use one verified runtime, unaffected by global CLI updates.
        var environment = ProcessInfo.processInfo.environment
        environment["BMUX_SOCKET_PATH"] = TerminalController.shared.activeSocketPath(preferredPath: SocketControlSettings.socketPath())
        environment["BMUX_BUNDLED_CLI_PATH"] = Bundle.main.resourceURL?.appendingPathComponent("bin/bmux").path
        environment["BMUX_BUNDLE_ID"] = Bundle.main.bundleIdentifier
        let runtime = ManagedCodexRuntime(root: home.appendingPathComponent("Library/Application Support/bmux/runtimes/codex", isDirectory: true))
        let allowsProviderLaunch = BmuxAppRuntimeConfiguration.currentProcess().processKind == .productionApp
        let host = ConnectedCodexHostService(
            resolveExecutable: { directory, environment in
                guard allowsProviderLaunch else { throw BmuxAgentChat.CodexControlError.unsupported }
                let executable = try await runtime.executable()
                try Task.checkCancellation()
                return try await ConnectedCodexExecutableResolver(environment: environment)
                    .resolve(workingDirectory: directory, managedExecutable: executable)
            },
            root: home.appendingPathComponent("Library/Application Support/bmux/connected-codex", isDirectory: true),
            environment: environment,
            hookWrapper: Bundle.main.resourceURL?.appendingPathComponent("bin/bmux-codex-wrapper"))
        return TerminalChatRuntime(reader: transcript, hosts: host) { [weak transcript] thread, workspace, surface, directory in
            transcript?.noteResumeInitiated(sessionID: thread, source: "codex", surfaceID: surface.uuidString,
                                            workspaceID: workspace.uuidString, workingDirectory: directory)
        }
    }()
}
