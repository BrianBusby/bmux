import Foundation

/// Query parameters for reading the deterministic outcome of one observed coding-agent turn.
public struct ProvenanceTurnOutcomeRequest: Codable, Equatable, Sendable {
    /// Stable Provenance Engine turn projection identifier to read.
    public let turnID: String

    /// Specific outcome revision identifier to read, or `nil` for the latest revision.
    public let revisionID: String?

    /// Creates a turn-outcome request.
    ///
    /// - Parameters:
    ///   - turnID: Stable Provenance Engine turn projection identifier.
    ///   - revisionID: Specific outcome revision identifier, or `nil` for latest.
    public init(turnID: String, revisionID: String? = nil) {
        self.turnID = turnID
        self.revisionID = revisionID
    }
}
