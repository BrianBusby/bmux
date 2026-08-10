import Foundation

/// Query parameters for reading workspace display current state.
public struct ProvenanceWorkspaceDisplayRequest: Codable, Equatable, Sendable {
    /// Client workspace identifier to read.
    public let workspaceID: String

    /// Creates a workspace display current-state request.
    ///
    /// - Parameter workspaceID: Client workspace identifier to read.
    public init(workspaceID: String) {
        self.workspaceID = workspaceID
    }
}
