import Foundation

/// Production `git` command runner backed by `Process`.
struct WorkProvenanceProcessGitCommandRunner: WorkProvenanceGitCommandRunning {
    /// Absolute URL for the `git` executable.
    let executableURL: URL

    /// Creates a process-backed Git command runner.
    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/git")) {
        self.executableURL = executableURL
    }

    func runGit(arguments: [String], workingDirectory: String) async throws -> WorkProvenanceGitCommandResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? standardOutput.fileHandleForReading.close()
        try? standardError.fileHandleForReading.close()

        return WorkProvenanceGitCommandResult(
            exitCode: process.terminationStatus,
            standardOutput: outputData,
            standardError: errorData
        )
    }
}
