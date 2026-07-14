import Foundation

/// Reads Git state needed by the observe-only provenance runtime.
protocol WorkProvenanceGitInspecting: Sendable {
    /// Returns the Git snapshot for `directory`, or `nil` when it is not inside a repository.
    func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot?
}
