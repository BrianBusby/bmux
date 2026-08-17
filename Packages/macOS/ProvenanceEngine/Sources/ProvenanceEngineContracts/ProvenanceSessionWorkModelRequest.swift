import Foundation

/// Query parameters for reading the PE-owned work model for one coding-agent session.
public struct ProvenanceSessionWorkModelRequest: Codable, Equatable, Sendable {
    /// Provenance session identifier to read.
    public let sessionID: String

    /// Maximum detailed factual turns to include in the backing factual projection read.
    public let turnLimit: Int?

    /// Creates a SessionWorkModel query request.
    ///
    /// - Parameters:
    ///   - sessionID: Provenance session identifier to read.
    ///   - turnLimit: Maximum detailed factual turns to include.
    public init(sessionID: String, turnLimit: Int? = nil) {
        self.sessionID = sessionID
        self.turnLimit = turnLimit
    }
}
