import Foundation

/// Accepted evidence or projection reference supporting a related-session brief.
public struct ProvenanceRelatedSessionEvidenceReference: Codable, Equatable, Sendable {
    /// Reference kind, such as `event`, `session_outcome`, `session_work_model`, or `session_relationship`.
    public let kind: String

    /// Stable identifier for the referenced event, projection, or current-state record.
    public let id: String

    /// Optional event-ledger sequence.
    public let eventSequence: Int?

    /// Optional event type.
    public let eventType: String?

    /// Optional projection revision identifier.
    public let projectionRevisionID: String?

    /// Optional projection source evidence watermark.
    public let projectionWatermark: Int?

    /// Optional field or relationship field supported by the reference.
    public let field: String?

    /// Optional availability state of the referenced source.
    public let sourceState: String?

    /// Creates a related-session evidence reference.
    public init(
        kind: String,
        id: String,
        eventSequence: Int? = nil,
        eventType: String? = nil,
        projectionRevisionID: String? = nil,
        projectionWatermark: Int? = nil,
        field: String? = nil,
        sourceState: String? = nil
    ) {
        self.kind = kind
        self.id = id
        self.eventSequence = eventSequence
        self.eventType = eventType
        self.projectionRevisionID = projectionRevisionID
        self.projectionWatermark = projectionWatermark
        self.field = field
        self.sourceState = sourceState
    }
}
