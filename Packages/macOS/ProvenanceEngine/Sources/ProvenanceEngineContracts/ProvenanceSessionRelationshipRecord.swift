import Foundation

/// Current-state parent/root relationship for one agent session.
public struct ProvenanceSessionRelationshipRecord: Codable, Equatable, Sendable, Identifiable {
    /// Session whose relationship is being projected.
    public let sessionID: String

    /// Parent session that created or owns this child session.
    public let parentSessionID: String

    /// Root session at the top of the relationship tree.
    public let rootSessionID: String

    /// Inbound delegation contract, when modeled by a later phase.
    public let inboundDelegationID: String?

    /// Zero-based distance from the root session.
    public let depth: Int

    /// Evidence class behind the relationship.
    public let source: ProvenanceSource

    /// Confidence in the relationship projection.
    public let confidence: ProvenanceConfidence

    /// First observed time for this relationship.
    public let createdAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    /// Stable identifier, matching the child session identifier.
    public var id: String { sessionID }

    /// Creates a session relationship projection record.
    public init(
        sessionID: String,
        parentSessionID: String,
        rootSessionID: String,
        inboundDelegationID: String? = nil,
        depth: Int,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.sessionID = sessionID
        self.parentSessionID = parentSessionID
        self.rootSessionID = rootSessionID
        self.inboundDelegationID = inboundDelegationID
        self.depth = depth
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
