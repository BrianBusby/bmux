import Foundation

/// Request for focused provenance context about one repository-relative file path.
public struct ProvenanceFileExplanationRequest: Codable, Equatable, Sendable {
    /// Worktree identifier to query.
    public let worktreeID: String

    /// Repository-relative path to explain.
    public let path: String

    /// Creates a file-explanation request.
    public init(worktreeID: String, path: String) {
        self.worktreeID = worktreeID
        self.path = path
    }
}
