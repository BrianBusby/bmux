import Foundation

/// Temporal relationship between artifact observations in a collision candidate.
public struct ProvenanceArtifactCollisionTemporalOverlap: Codable, Equatable, Sendable {
    /// Temporal state, such as `temporally_overlapping_edits`, `ordered_edits`, or `missing_timestamps`.
    public let state: String

    /// Earliest artifact observation across participants.
    public let firstObservedChangedAt: Date?

    /// Latest artifact observation across participants.
    public let lastObservedChangedAt: Date?

    /// Participating sessions without enough timestamp evidence.
    public let missingTimestampSessionIDs: [String]

    /// Evidence references supporting the temporal state.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates a temporal-overlap record.
    public init(
        state: String,
        firstObservedChangedAt: Date?,
        lastObservedChangedAt: Date?,
        missingTimestampSessionIDs: [String],
        evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) {
        self.state = state
        self.firstObservedChangedAt = firstObservedChangedAt
        self.lastObservedChangedAt = lastObservedChangedAt
        self.missingTimestampSessionIDs = missingTimestampSessionIDs
        self.evidence = evidence
    }
}
