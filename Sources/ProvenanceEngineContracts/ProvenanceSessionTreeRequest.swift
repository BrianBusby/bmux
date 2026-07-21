import Foundation

/// Request for a bounded provenance session-tree query.
public struct ProvenanceSessionTreeRequest: Codable, Equatable, Sendable {
    /// Root session identifier requested by the caller.
    public let rootSessionID: String

    /// Maximum number of session and relationship rows to return.
    public let limit: Int?

    /// Creates a session-tree query request.
    public init(rootSessionID: String, limit: Int? = nil) {
        self.rootSessionID = rootSessionID
        self.limit = limit
    }
}
