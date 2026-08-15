import Foundation

/// Query parameters for reading the factual projection for one coding-agent session.
public struct ProvenanceFactualSessionProjectionRequest: Codable, Equatable, Sendable {
    /// Provenance session identifier to read.
    public let sessionID: String

    /// Maximum number of turn snapshots to return.
    public let turnLimit: Int?

    /// Creates a factual session projection request.
    ///
    /// - Parameters:
    ///   - sessionID: Provenance session identifier to read.
    ///   - turnLimit: Optional maximum number of turn snapshots to return.
    public init(sessionID: String, turnLimit: Int? = nil) {
        self.sessionID = sessionID
        self.turnLimit = turnLimit
    }
}
