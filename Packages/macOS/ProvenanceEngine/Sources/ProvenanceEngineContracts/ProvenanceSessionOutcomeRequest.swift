import Foundation

/// Query parameters for reading the deterministic outcome of one coding-agent session.
public struct ProvenanceSessionOutcomeRequest: Codable, Equatable, Sendable {
    /// Stable Provenance Engine session projection identifier to read.
    public let sessionID: String

    /// Specific session-outcome revision identifier to read, or `nil` for the latest revision.
    public let revisionID: String?

    /// Creates a session-outcome request.
    ///
    /// - Parameters:
    ///   - sessionID: Stable Provenance Engine session projection identifier.
    ///   - revisionID: Specific outcome revision identifier, or `nil` for latest.
    public init(sessionID: String, revisionID: String? = nil) {
        self.sessionID = sessionID
        self.revisionID = revisionID
    }
}
