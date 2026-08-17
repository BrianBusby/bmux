import Foundation

/// Bounded domain response for a provenance session-tree query.
public struct ProvenanceSessionTreeResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Root session identifier requested by the caller.
    public let rootSessionID: String

    /// Whether any authoritative session-tree records were found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Sessions included in depth-first relationship order.
    public let sessions: [ProvenanceSessionRecord]

    /// Parent-child relationships included in tree order.
    public let relationships: [ProvenanceSessionRelationshipRecord]

    /// External identities linked to returned sessions.
    public let externalIdentities: [ProvenanceExternalIdentityRecord]

    /// Creates a session-tree response.
    public init(
        schemaVersion: Int = 1,
        rootSessionID: String,
        found: Bool,
        reason: String? = nil,
        sessions: [ProvenanceSessionRecord],
        relationships: [ProvenanceSessionRelationshipRecord],
        externalIdentities: [ProvenanceExternalIdentityRecord]
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
