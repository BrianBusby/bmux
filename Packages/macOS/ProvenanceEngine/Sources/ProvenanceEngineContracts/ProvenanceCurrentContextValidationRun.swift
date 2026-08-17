import Foundation

/// Validation-run row returned by a current-context query.
public struct ProvenanceCurrentContextValidationRun: Codable, Equatable, Sendable {
    /// Validation-run projection.
    public let validationRun: ProvenanceValidationRunRecord

    /// Checkpoint linked to the validation run, when available.
    public let checkpoint: ProvenanceCheckpointRecord?

    /// Contribution linked to the validation run or checkpoint, when available.
    public let contribution: ProvenanceContributionRecord?

    /// Creates a current-context validation-run row.
    public init(
        validationRun: ProvenanceValidationRunRecord,
        checkpoint: ProvenanceCheckpointRecord?,
        contribution: ProvenanceContributionRecord?
    ) {
        self.validationRun = validationRun
        self.checkpoint = checkpoint
        self.contribution = contribution
    }
}
