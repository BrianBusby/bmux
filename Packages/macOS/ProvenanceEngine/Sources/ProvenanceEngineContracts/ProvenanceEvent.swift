import Foundation

/// One immutable event in the provenance ledger.
public struct ProvenanceEvent: Codable, Equatable, Sendable, Identifiable {
    /// Stable event identifier.
    public let id: String

    /// Event schema version.
    public let schemaVersion: Int

    /// Semantic event type.
    public let eventType: ProvenanceEventType

    /// Event creation time.
    public let timestamp: Date

    /// Repository this event is scoped to, when known.
    public let repositoryID: String?

    /// Worktree this event is scoped to, when known.
    public let worktreeID: String?

    /// Agent session this event is scoped to, when known.
    public let sessionID: String?

    /// Work contribution this event is scoped to, when known.
    public let contributionID: String?

    /// Evidence class behind the event.
    public let source: ProvenanceSource

    /// System that produced the evidence event, when known.
    public let evidenceOrigin: ProvenanceEvidenceOrigin?

    /// Ownership boundary for the evidence event, when known.
    public let evidenceScope: ProvenanceEvidenceScope?

    /// Confidence in the event's semantic interpretation.
    public let confidence: ProvenanceConfidence

    /// Typed payload used to update current-state projections.
    public let payload: ProvenanceEventPayload

    /// Creates a provenance event.
    public init(
        id: String = UUID().uuidString,
        schemaVersion: Int = 1,
        eventType: ProvenanceEventType,
        timestamp: Date = Date(),
        repositoryID: String? = nil,
        worktreeID: String? = nil,
        sessionID: String? = nil,
        contributionID: String? = nil,
        source: ProvenanceSource,
        evidenceOrigin: ProvenanceEvidenceOrigin? = nil,
        evidenceScope: ProvenanceEvidenceScope? = nil,
        confidence: ProvenanceConfidence,
        payload: ProvenanceEventPayload = ProvenanceEventPayload()
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.eventType = eventType
        self.timestamp = timestamp
        self.repositoryID = repositoryID
        self.worktreeID = worktreeID
        self.sessionID = sessionID
        self.contributionID = contributionID
        self.source = source
        self.evidenceOrigin = evidenceOrigin
        self.evidenceScope = evidenceScope
        self.confidence = confidence
        self.payload = payload
    }
}
