import Foundation

/// Revisioned response for one factual coding-agent turn detail snapshot.
public struct ProvenanceFactualSessionTurnDetailResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether factual turn detail was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Stable Provenance Engine turn projection identifier requested by the caller.
    public let turnID: String

    /// Provenance session that owns the turn, when found.
    public let sessionID: String?

    /// Monotonically increasing ledger revision for the owning session, when found.
    public let revision: Int?

    /// Factual turn detail, when found.
    public let turnDetail: ProvenanceFactualSessionProjectionTurnSnapshot?

    /// Creates a factual turn-detail response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        turnID: String,
        sessionID: String? = nil,
        revision: Int? = nil,
        turnDetail: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.turnID = turnID
        self.sessionID = sessionID
        self.revision = revision
        self.turnDetail = turnDetail
    }
}
