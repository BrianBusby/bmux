import BmuxAgentChat
import BmuxFoundation
import Foundation

/// Resolves each new host through the user's shell-initialized PATH without adding other installations.
struct ConnectedCodexExecutableResolver: Sendable {
    let environment: [String: String]
    let commands: any CommandRunning

    init(environment: [String: String], commands: (any CommandRunning)? = nil) {
        self.environment = environment
        self.commands = commands ?? CommandRunner(environment: environment)
    }

    func resolve(workingDirectory: String) async throws -> AgentSessionLaunchPlan {
        let shell = environment["SHELL"] ?? "/bin/zsh"
        guard shell.hasPrefix("/") else {
            throw CodexControlError.unsupported
        }
        // csh/tcsh reject login mode when a command is supplied; their interactive startup still reads the rc file.
        let shellName = URL(fileURLWithPath: shell).resolvingSymlinksInPath().lastPathComponent
        let flags = ["csh", "tcsh"].contains(shellName) ? ["-i", "-c"] : ["-lic"]
        // The script is fixed, never derived from recorded commands. Capture only PATH, not secrets from the environment.
        let output = await commands.runStandardOutput(directory: workingDirectory, executable: shell,
            arguments: flags + ["printf '\\000BMUX_CODEX_PATH\\000'; /usr/bin/printenv PATH"], timeout: 5)
        guard let output, output.utf8.count <= 65_536,
              let marker = output.range(of: "\0BMUX_CODEX_PATH\0", options: .backwards) else {
            throw CodexControlError.disconnected
        }
        var path = String(output[marker.upperBound...])
        if path.hasSuffix("\n") { path.removeLast() }
        guard !path.isEmpty, !path.contains("\n"), !path.contains("\0") else { throw CodexControlError.disconnected }
        var resolvedEnvironment = environment
        resolvedEnvironment["PATH"] = path
        return try AgentExecutableResolver(environment: resolvedEnvironment,
            includeStandardSearchDirectories: false, includeUserRuntimeSearchDirectories: false).resolve(.codex)
    }
}
