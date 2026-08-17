import Foundation

/// Query parameters for reading factual detail for one observed coding-agent turn.
public struct ProvenanceFactualSessionTurnDetailRequest: Codable, Equatable, Sendable {
    /// Stable Provenance Engine turn projection identifier to read.
    public let turnID: String

    /// Creates a factual turn-detail request.
    ///
    /// - Parameter turnID: Stable Provenance Engine turn projection identifier.
    public init(turnID: String) {
        self.turnID = turnID
    }
}
