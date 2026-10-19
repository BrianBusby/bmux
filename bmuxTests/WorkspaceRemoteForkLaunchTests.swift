import BmuxCore
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct WorkspaceRemoteForkLaunchTests {
    @Test
    func preservesRemoteContext() throws {
        let workspace = Workspace()
        defer { workspace.teardownAllPanels() }
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("fork-agent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let agentSocketPath = root.appendingPathComponent("agent.sock").path
        // Resolution checks existence only; no agent traffic or remote connection is started.
        try Data().write(to: URL(fileURLWithPath: agentSocketPath))
        workspace.configureRemoteConnection(
            WorkspaceRemoteConfiguration(
                destination: "bmux-macmini",
                port: 2222,
                identityFile: "/Users/example/.ssh/bmux",
                sshOptions: ["ServerAliveInterval=30", "ForwardAgent=yes"],
                localProxyPort: nil,
                relayPort: 64000,
                relayID: "relay-fork",
                relayToken: String(repeating: "a", count: 64),
                localSocketPath: "/tmp/bmux-fork-remote.sock",
                terminalStartupCommand: "ssh -p 2222 -i /Users/example/.ssh/bmux -o ServerAliveInterval=30 -o ForwardAgent=yes -tt bmux-macmini",
                agentSocketPath: agentSocketPath
            ),
            autoConnect: false
        )
        let sourcePanelId = try #require(workspace.focusedPanelId)
        let snapshot = SessionRestorableAgentSnapshot(
            kind: .codex,
            sessionId: "019dad34-d218-7943-b81a-eddac5c87951",
            workingDirectory: "/Users/bmux/project",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "codex",
                executablePath: "/Users/example/.bun/bin/codex",
                arguments: ["/Users/example/.bun/bin/codex"],
                workingDirectory: "/Users/bmux/project",
                environment: nil,
                capturedAt: 123,
                source: "process"
            )
        )

        let launch = try #require(
            workspace.forkAgentWorkspaceLaunch(
                fromPanelId: sourcePanelId,
                snapshot: snapshot
            )
        )

        #expect(launch.workingDirectory == "/Users/bmux/project")
        #expect(launch.terminalWorkingDirectory == nil)
        #expect(launch.initialTerminalCommand == "ssh -p 2222 -i /Users/example/.ssh/bmux -o ServerAliveInterval=30 -o ForwardAgent=yes -tt bmux-macmini")
        #expect(launch.initialTerminalInput == snapshot.forkCommand.map { $0 + "\n" })
        #expect(launch.initialTerminalEnvironment["SSH_AUTH_SOCK"] == agentSocketPath)
        #expect(launch.autoConnectRemoteConfiguration)
        #expect(launch.remoteConfiguration?.destination == "bmux-macmini")
        #expect(launch.remoteConfiguration?.port == 2222)
        #expect(launch.remoteConfiguration?.identityFile == "/Users/example/.ssh/bmux")
        #expect(launch.remoteConfiguration?.sshOptions == ["ServerAliveInterval=30", "ForwardAgent=yes"])
        #expect(launch.remoteConfiguration?.agentSocketPath == agentSocketPath)
        #expect(launch.remoteConfiguration?.sshTerminalStartupEnvironment?["SSH_AUTH_SOCK"] == agentSocketPath)
        #expect(launch.remoteConfiguration?.sshProcessEnvironment?["SSH_AUTH_SOCK"] == agentSocketPath)
        #expect(launch.remoteConfiguration?.relayPort == nil)
        #expect(launch.remoteConfiguration?.localSocketPath == nil)
    }
}
