import Foundation

/// Active session row returned by a current-context query.
struct ProvenanceCurrentContextSession: Codable, Equatable, Sendable {
    /// Session projection.
    let session: WorkProvenanceSessionRecord

    /// Active contribution linked to the session, when available.
    let contribution: WorkProvenanceContributionRecord?

    /// Work item linked to the contribution, when available.
    let workItem: WorkProvenanceWorkItemRecord?

    /// Creates a current-context session row.
    init(
        session: WorkProvenanceSessionRecord,
        contribution: WorkProvenanceContributionRecord?,
        workItem: WorkProvenanceWorkItemRecord?
    ) {
        self.session = session
        self.contribution = contribution
        self.workItem = workItem
    }
}
