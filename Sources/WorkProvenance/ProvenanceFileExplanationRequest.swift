import Foundation

/// Request for focused provenance context about one repository-relative file path.
struct ProvenanceFileExplanationRequest: Codable, Equatable, Sendable {
    /// Worktree identifier to query.
    let worktreeID: String

    /// Repository-relative path to explain.
    let path: String

    /// Creates a file-explanation request.
    init(worktreeID: String, path: String) {
        self.worktreeID = worktreeID
        self.path = path
    }
}
