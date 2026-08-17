import Foundation

/// External identifier linked to a provenance session.
public struct ProvenanceExternalIdentityRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable identity-link identifier.
    public let id: String

    /// Provenance session that owns the external identity.
    public let sessionID: String

    /// External system name, such as `codex`, `claude`, or a client name.
    public let system: String

    /// External identifier kind, such as `thread`, `subsession`, or `request`.
    public let kind: String

    /// External identifier value.
    public let externalID: String

    /// Evidence class behind the identity link.
    public let source: ProvenanceSource

    /// Confidence in the identity link.
    public let confidence: ProvenanceConfidence

    /// First observed time for this identity link.
    public let createdAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates an external identity projection record.
    public init(
        id: String,
        sessionID: String,
        system: String,
        kind: String,
        externalID: String,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.system = system
        self.kind = kind
        self.externalID = externalID
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
