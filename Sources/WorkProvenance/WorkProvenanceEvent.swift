import Foundation

/// One immutable event in the work provenance ledger.
struct WorkProvenanceEvent: Codable, Equatable, Sendable, Identifiable {
    /// Stable event identifier.
    let id: String

    /// Event schema version.
    let schemaVersion: Int

    /// Semantic event type.
    let eventType: WorkProvenanceEventType

    /// Event creation time.
    let timestamp: Date

    /// Repository this event is scoped to, when known.
    let repositoryID: String?

    /// Worktree this event is scoped to, when known.
    let worktreeID: String?

    /// Agent session this event is scoped to, when known.
    let sessionID: String?

    /// Work contribution this event is scoped to, when known.
    let contributionID: String?

    /// Evidence class behind the event.
    let source: WorkProvenanceSource

    /// Confidence in the event's semantic interpretation.
    let confidence: WorkProvenanceConfidence

    /// Typed payload used to update current-state projections.
    let payload: WorkProvenanceEventPayload

    /// Creates a provenance event.
    init(
        id: String = UUID().uuidString,
        schemaVersion: Int = 1,
        eventType: WorkProvenanceEventType,
        timestamp: Date = Date(),
        repositoryID: String? = nil,
        worktreeID: String? = nil,
        sessionID: String? = nil,
        contributionID: String? = nil,
        source: WorkProvenanceSource,
        confidence: WorkProvenanceConfidence,
        payload: WorkProvenanceEventPayload = WorkProvenanceEventPayload()
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
        self.confidence = confidence
        self.payload = payload
    }
}
