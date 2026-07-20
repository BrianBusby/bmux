import Foundation

/// External identifier linked to a provenance session.
struct WorkProvenanceExternalIdentityRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable identity-link identifier.
    let id: String

    /// Provenance session that owns the external identity.
    let sessionID: String

    /// External system name, such as `codex`, `claude`, or `bmux`.
    let system: String

    /// External identifier kind, such as `thread`, `subsession`, or `request`.
    let kind: String

    /// External identifier value.
    let externalID: String

    /// Evidence class behind the identity link.
    let source: WorkProvenanceSource

    /// Confidence in the identity link.
    let confidence: WorkProvenanceConfidence

    /// First observed time for this identity link.
    let createdAt: Date

    /// Last projection update time.
    let updatedAt: Date

    /// Creates an external identity projection record.
    init(
        id: String,
        sessionID: String,
        system: String,
        kind: String,
        externalID: String,
        source: WorkProvenanceSource,
        confidence: WorkProvenanceConfidence,
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
