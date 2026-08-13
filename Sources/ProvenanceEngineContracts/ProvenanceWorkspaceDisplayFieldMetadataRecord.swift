import Foundation

/// Provenance metadata for one workspace-display Current State field.
public struct ProvenanceWorkspaceDisplayFieldMetadataRecord: Codable, Equatable, Sendable {
    /// Stable workspace-display field name, such as `branch` or `pull_request_status`.
    public let fieldName: String

    /// Time this field value or explicit clear was observed.
    public let observedAt: Date

    /// Evidence class behind the accepted field state.
    public let source: ProvenanceSource

    /// System that produced the accepted field state, when known.
    public let evidenceOrigin: ProvenanceEvidenceOrigin?

    /// Ledger event that last changed this field state, when known.
    public let evidenceEventID: String?

    /// Append-order ledger sequence that last changed this field state, when known.
    public let evidenceEventSequence: Int?

    /// Internal freshness marker for diagnostics and refresh policy.
    public let freshness: String

    /// Whether this field was last changed by affirmative clear evidence.
    public let isExplicitlyCleared: Bool

    /// Creates field-level workspace-display provenance metadata.
    public init(
        fieldName: String,
        observedAt: Date,
        source: ProvenanceSource,
        evidenceOrigin: ProvenanceEvidenceOrigin? = nil,
        evidenceEventID: String? = nil,
        evidenceEventSequence: Int? = nil,
        freshness: String = "current",
        isExplicitlyCleared: Bool = false
    ) {
        self.fieldName = fieldName
        self.observedAt = observedAt
        self.source = source
        self.evidenceOrigin = evidenceOrigin
        self.evidenceEventID = evidenceEventID
        self.evidenceEventSequence = evidenceEventSequence
        self.freshness = freshness
        self.isExplicitlyCleared = isExplicitlyCleared
    }
}
