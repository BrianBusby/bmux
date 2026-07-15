import Foundation

/// Current-state projection for a contribution checkpoint.
struct WorkProvenanceCheckpointRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable checkpoint identifier.
    let id: String

    /// Owning contribution identifier.
    let contributionID: String

    /// Contribution-local sequence number.
    let sequence: Int

    /// Git HEAD observed at the checkpoint, when known.
    let gitHEAD: String?

    /// Fingerprint of the relevant diff, when known.
    let diffFingerprint: String?

    /// Semantic summary, declared or inferred.
    let summary: String?

    /// Checkpoint status such as `in_progress`, `completed`, or `interrupted`.
    let status: String

    /// Validation state such as `not_run`, `passed`, `failed`, or `stale`.
    let validationState: String?

    /// Confidence in the semantic summary.
    let semanticConfidence: WorkProvenanceConfidence

    /// Freshness marker such as `fresh` or `stale`.
    let freshness: String

    /// Checkpoint creation time.
    let createdAt: Date

    /// Creates a checkpoint projection record.
    init(
        id: String,
        contributionID: String,
        sequence: Int,
        gitHEAD: String? = nil,
        diffFingerprint: String? = nil,
        summary: String? = nil,
        status: String,
        validationState: String? = nil,
        semanticConfidence: WorkProvenanceConfidence,
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
