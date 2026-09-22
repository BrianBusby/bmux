import Foundation

/// Executable composition for transcript observation and opt-in shared hosts.
@MainActor
final class AgentChatApplicationRuntime {
    let transcript = AgentChatTranscriptService()
    lazy var terminal: TerminalChatRuntime = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let plan = try? AgentExecutableResolver().resolve(.codex)
        // GUI launch environments commonly omit ~/.local/bin. Prefer the
        // user-installed Codex binary when present; launch still fails closed
        // below unless its exact empirically verified version is available.
        let localCodex = home.appendingPathComponent(".local/bin/codex")
        let executable = FileManager.default.isExecutableFile(atPath: localCodex.path)
            ? localCodex : (plan?.executableURL ?? localCodex)
        let host = ConnectedCodexHostService(executable: executable,
            root: home.appendingPathComponent("Library/Application Support/bmux/connected-codex", isDirectory: true),
            environment: plan?.environment ?? ProcessInfo.processInfo.environment)
        return TerminalChatRuntime(reader: transcript, hosts: host) { [weak transcript] thread, workspace, surface, directory in
            transcript?.noteResumeInitiated(sessionID: thread, source: "codex", surfaceID: surface.uuidString,
                                            workspaceID: workspace.uuidString, workingDirectory: directory)
        }
    }()
}
