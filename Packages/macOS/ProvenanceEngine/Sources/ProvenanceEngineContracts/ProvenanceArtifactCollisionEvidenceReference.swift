/// Evidence, current-state, or projection reference supporting an artifact-collision fact.
public struct ProvenanceArtifactCollisionEvidenceReference: Codable, Equatable, Sendable {
    /// Reference kind, such as `event`, `session_outcome`, `related_session_projection`, or `worktree`.
    public let kind: String

    /// Stable identifier for the referenced evidence or projection record.
    public let id: String

    /// Optional event-ledger sequence.
    public let eventSequence: Int?

    /// Optional event type.
    public let eventType: String?

    /// Evidence claim classification when the reference points at accepted evidence.
    public let source: ProvenanceSource?

    /// Producing system for event evidence, when known.
    public let evidenceOrigin: ProvenanceEvidenceOrigin?

    /// Ownership boundary for event evidence, when known.
    public let evidenceScope: ProvenanceEvidenceScope?

    /// Optional projection revision identifier.
    public let projectionRevisionID: String?

    /// Optional projection source evidence watermark.
    public let projectionWatermark: Int?

    /// Provenance session owning the referenced fact, when applicable.
    public let sessionID: String?

    /// Provenance turn owning the referenced fact, when applicable.
    public let turnID: String?

    /// Field, relationship, or record-kind label supported by the reference.
    public let field: String?

    /// Source availability state used by the upstream projection.
    public let sourceState: String?

    /// Creates an artifact-collision evidence reference.
    public init(
        kind: String,
        id: String,
        eventSequence: Int? = nil,
        eventType: String? = nil,
        source: ProvenanceSource? = nil,
        evidenceOrigin: ProvenanceEvidenceOrigin? = nil,
        evidenceScope: ProvenanceEvidenceScope? = nil,
        projectionRevisionID: String? = nil,
        projectionWatermark: Int? = nil,
        sessionID: String? = nil,
        turnID: String? = nil,
        field: String? = nil,
        sourceState: String? = nil
    ) {
        self.kind = kind
        self.id = id
        self.eventSequence = eventSequence
        self.eventType = eventType
        self.source = source
        self.evidenceOrigin = evidenceOrigin
        self.evidenceScope = evidenceScope
        self.projectionRevisionID = projectionRevisionID
        self.projectionWatermark = projectionWatermark
        self.sessionID = sessionID
        self.turnID = turnID
        self.field = field
        self.sourceState = sourceState
    }
}
