import Foundation

/// Checkpoint row returned by a current-context query.
struct ProvenanceCurrentContextCheckpoint: Codable, Equatable, Sendable {
    /// Checkpoint projection.
    let checkpoint: WorkProvenanceCheckpointRecord

    /// Contribution linked to the checkpoint.
    let contribution: WorkProvenanceContributionRecord

    /// Session linked to the contribution, when available.
    let session: WorkProvenanceSessionRecord?

    /// Work item linked to the contribution, when available.
    let workItem: WorkProvenanceWorkItemRecord?

    /// Creates a current-context checkpoint row.
    init(
        checkpoint: WorkProvenanceCheckpointRecord,
        contribution: WorkProvenanceContributionRecord,
        session: WorkProvenanceSessionRecord?,
        workItem: WorkProvenanceWorkItemRecord?
    ) {
        self.checkpoint = checkpoint
        self.contribution = contribution
        self.session = session
        self.workItem = workItem
    }
}
