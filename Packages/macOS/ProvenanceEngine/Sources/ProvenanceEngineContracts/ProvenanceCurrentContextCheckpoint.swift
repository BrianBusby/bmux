import Foundation

/// Checkpoint row returned by a current-context query.
public struct ProvenanceCurrentContextCheckpoint: Codable, Equatable, Sendable {
    /// Checkpoint projection.
    public let checkpoint: ProvenanceCheckpointRecord

    /// Contribution linked to the checkpoint.
    public let contribution: ProvenanceContributionRecord

    /// Session linked to the contribution, when available.
    public let session: ProvenanceSessionRecord?

    /// Work item linked to the contribution, when available.
    public let workItem: ProvenanceWorkItemRecord?

    /// Creates a current-context checkpoint row.
    public init(
        checkpoint: ProvenanceCheckpointRecord,
        contribution: ProvenanceContributionRecord,
        session: ProvenanceSessionRecord?,
        workItem: ProvenanceWorkItemRecord?
    ) {
        self.checkpoint = checkpoint
        self.contribution = contribution
        self.session = session
        self.workItem = workItem
    }
}
