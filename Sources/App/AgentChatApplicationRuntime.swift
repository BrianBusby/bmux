import Foundation

/// Executable composition for transcript observation and opt-in shared hosts.
@MainActor
final class AgentChatApplicationRuntime {
    let transcript = AgentChatTranscriptService()
    lazy var terminal: TerminalChatRuntime = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let plan = try? AgentExecutableResolver().resolve(.codex)
        let executable = plan?.executableURL ?? home.appendingPathComponent(".local/bin/codex")
        let host = ConnectedCodexHostService(executable: executable,
            root: home.appendingPathComponent("Library/Application Support/bmux/connected-codex", isDirectory: true),
            environment: plan?.environment ?? ProcessInfo.processInfo.environment)
        return TerminalChatRuntime(reader: transcript, hosts: host) { [weak transcript] thread, workspace, surface, directory in
            transcript?.noteResumeInitiated(sessionID: thread, source: "codex", surfaceID: surface.uuidString,
                                            workspaceID: workspace.uuidString, workingDirectory: directory)
        }
    }()
}
