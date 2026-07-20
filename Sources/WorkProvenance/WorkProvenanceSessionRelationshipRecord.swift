import Foundation

/// Current-state parent/root relationship for one agent session.
struct WorkProvenanceSessionRelationshipRecord: Codable, Equatable, Sendable, Identifiable {
    /// Session whose relationship is being projected.
    let sessionID: String

    /// Parent session that created or owns this child session.
    let parentSessionID: String

    /// Root session at the top of the relationship tree.
    let rootSessionID: String

    /// Inbound delegation contract, when modeled by a later phase.
    let inboundDelegationID: String?

    /// Zero-based distance from the root session.
    let depth: Int

    /// Evidence class behind the relationship.
    let source: WorkProvenanceSource

    /// Confidence in the relationship projection.
    let confidence: WorkProvenanceConfidence

    /// First observed time for this relationship.
    let createdAt: Date

    /// Last projection update time.
    let updatedAt: Date

    /// Stable identifier, matching the child session identifier.
    var id: String { sessionID }

    /// Creates a session relationship projection record.
    init(
        sessionID: String,
        parentSessionID: String,
        rootSessionID: String,
        inboundDelegationID: String? = nil,
        depth: Int,
        source: WorkProvenanceSource,
        confidence: WorkProvenanceConfidence,
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
