import Foundation

/// Current-state projection for a contribution checkpoint.
public struct ProvenanceCheckpointRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable checkpoint identifier.
    public let id: String

    /// Owning contribution identifier.
    public let contributionID: String

    /// Contribution-local sequence number.
    public let sequence: Int

    /// Git HEAD observed at the checkpoint, when known.
    public let gitHEAD: String?

    /// Fingerprint of the relevant diff, when known.
    public let diffFingerprint: String?

    /// Semantic summary, declared or inferred.
    public let summary: String?

    /// Checkpoint status such as `in_progress`, `completed`, or `interrupted`.
    public let status: String

    /// Validation state such as `not_run`, `passed`, `failed`, or `stale`.
    public let validationState: String?

    /// Confidence in the semantic summary.
    public let semanticConfidence: ProvenanceConfidence

    /// Freshness marker such as `fresh` or `stale`.
    public let freshness: String

    /// Checkpoint creation time.
    public let createdAt: Date

    /// Creates a checkpoint projection record.
    public init(
        id: String,
        contributionID: String,
        sequence: Int,
        gitHEAD: String? = nil,
        diffFingerprint: String? = nil,
        summary: String? = nil,
        status: String,
        validationState: String? = nil,
        semanticConfidence: ProvenanceConfidence,
        freshness: String,
        createdAt: Date
    ) {
        self.id = id
        self.contributionID = contributionID
        self.sequence = sequence
        self.gitHEAD = gitHEAD
        self.diffFingerprint = diffFingerprint
        self.summary = summary
        self.status = status
        self.validationState = validationState
        self.semanticConfidence = semanticConfidence
        self.freshness = freshness
        self.createdAt = createdAt
    }
}
