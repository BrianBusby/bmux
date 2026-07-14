import Foundation

/// Runs `git` commands for observe-only work provenance collection.
protocol WorkProvenanceGitCommandRunning: Sendable {
    /// Runs `git` with the provided arguments.
    ///
    /// - Parameters:
    ///   - arguments: Arguments passed to the `git` executable.
    ///   - workingDirectory: Directory used as the subprocess working directory.
    /// - Returns: Captured process output and exit status.
    func runGit(arguments: [String], workingDirectory: String) async throws -> WorkProvenanceGitCommandResult
}
