import BmuxSettings
import Foundation

/// Executable composition for transcript observation and opt-in shared hosts.
@MainActor
final class AgentChatApplicationRuntime {
    let transcript = AgentChatTranscriptService()
    lazy var terminal: TerminalChatRuntime = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Resolve the selected CLI afresh through the login shell for each new host.
        var environment = ProcessInfo.processInfo.environment
        environment["BMUX_SOCKET_PATH"] = TerminalController.shared.activeSocketPath(preferredPath: SocketControlSettings.socketPath())
        environment["BMUX_BUNDLED_CLI_PATH"] = Bundle.main.resourceURL?.appendingPathComponent("bin/bmux").path
        environment["BMUX_BUNDLE_ID"] = Bundle.main.bundleIdentifier
        let host = ConnectedCodexHostService(
            root: home.appendingPathComponent("Library/Application Support/bmux/connected-codex", isDirectory: true),
            environment: environment,
            hookWrapper: Bundle.main.resourceURL?.appendingPathComponent("bin/bmux-codex-wrapper"))
        return TerminalChatRuntime(reader: transcript, hosts: host) { [weak transcript] thread, workspace, surface, directory in
            transcript?.noteResumeInitiated(sessionID: thread, source: "codex", surfaceID: surface.uuidString,
                                            workspaceID: workspace.uuidString, workingDirectory: directory)
        }
    }()
}
