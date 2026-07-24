import Foundation

/// Validation-run row returned by a current-context query.
struct ProvenanceCurrentContextValidationRun: Codable, Equatable, Sendable {
    /// Validation-run projection.
    let validationRun: WorkProvenanceValidationRunRecord

    /// Checkpoint linked to the validation run, when available.
    let checkpoint: WorkProvenanceCheckpointRecord?

    /// Contribution linked to the validation run or checkpoint, when available.
    let contribution: WorkProvenanceContributionRecord?

    /// Creates a current-context validation-run row.
    init(
        validationRun: WorkProvenanceValidationRunRecord,
        checkpoint: WorkProvenanceCheckpointRecord?,
        contribution: WorkProvenanceContributionRecord?
    ) {
        self.validationRun = validationRun
        self.checkpoint = checkpoint
        self.contribution = contribution
    }
}
