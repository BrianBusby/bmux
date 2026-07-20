import Foundation

/// Bounded domain response for a provenance session-tree query.
struct ProvenanceSessionTreeResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    let schemaVersion: Int

    /// Root session identifier requested by the caller.
    let rootSessionID: String

    /// Whether any authoritative session-tree records were found.
    let found: Bool

    /// Stable reason code when `found` is false.
    let reason: String?

    /// Sessions included in depth-first relationship order.
    let sessions: [WorkProvenanceSessionRecord]

    /// Parent-child relationships included in tree order.
    let relationships: [WorkProvenanceSessionRelationshipRecord]

    /// External identities linked to returned sessions.
    let externalIdentities: [WorkProvenanceExternalIdentityRecord]

    /// Creates a session-tree response.
    init(
        schemaVersion: Int = 1,
        rootSessionID: String,
        found: Bool,
        reason: String? = nil,
        sessions: [WorkProvenanceSessionRecord],
        relationships: [WorkProvenanceSessionRelationshipRecord],
        externalIdentities: [WorkProvenanceExternalIdentityRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.rootSessionID = rootSessionID
        self.found = found
        self.reason = reason
        self.sessions = sessions
        self.relationships = relationships
        self.externalIdentities = externalIdentities
    }
}
