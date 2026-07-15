import Foundation

/// Result from one `git` subprocess used by work provenance observation.
struct WorkProvenanceGitCommandResult: Sendable {
    /// Process exit status.
    let exitCode: Int32

    /// Bytes written to standard output.
    let standardOutput: Data

    /// Bytes written to standard error.
    let standardError: Data
}
