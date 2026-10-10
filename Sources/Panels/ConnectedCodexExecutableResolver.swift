import BmuxAgentChat
import BmuxFoundation
import Foundation

/// Preserves shell tool discovery while allowing a connected session to use its managed provider.
struct ConnectedCodexExecutableResolver: Sendable {
    let environment: [String: String]
    let commands: any CommandRunning

    init(environment: [String: String], commands: (any CommandRunning)? = nil) {
        self.environment = environment
        self.commands = commands ?? CommandRunner(environment: environment)
    }

    func resolve(workingDirectory: String, managedExecutable: URL? = nil) async throws -> AgentSessionLaunchPlan {
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
        guard !path.contains("\n"), !path.contains("\0") else { throw CodexControlError.disconnected }
        var resolvedEnvironment = environment
        // Shell PATH treats empty entries as cwd and relative entries relative to the launch directory.
        let directory = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        resolvedEnvironment["PATH"] = path.components(separatedBy: ":").map { component in
            if component.hasPrefix("/") { return component }
            return component.isEmpty ? directory.standardizedFileURL.path
                : directory.appendingPathComponent(component, isDirectory: true).standardizedFileURL.path
        }.joined(separator: ":")
        if let managedExecutable {
            return AgentSessionLaunchPlan(provider: .codex, executableURL: managedExecutable, arguments: [], environment: resolvedEnvironment)
        }
        return try AgentExecutableResolver(environment: resolvedEnvironment,
            includeStandardSearchDirectories: false, includeUserRuntimeSearchDirectories: false).resolve(.codex)
    }
}
