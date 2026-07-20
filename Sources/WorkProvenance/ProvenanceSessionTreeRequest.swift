import Foundation

/// Request for a bounded provenance session-tree query.
struct ProvenanceSessionTreeRequest: Codable, Equatable, Sendable {
    /// Root session identifier requested by the caller.
    let rootSessionID: String

    /// Maximum number of session and relationship rows to return.
    let limit: Int?

    /// Creates a session-tree query request.
    init(rootSessionID: String, limit: Int? = nil) {
        self.rootSessionID = rootSessionID
        self.limit = limit
    }
}
