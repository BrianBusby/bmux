import Foundation

/// Active session row returned by a current-context query.
public struct ProvenanceCurrentContextSession: Codable, Equatable, Sendable {
    /// Session projection.
    public let session: ProvenanceSessionRecord

    /// Active contribution linked to the session, when available.
    public let contribution: ProvenanceContributionRecord?

    /// Work item linked to the contribution, when available.
    public let workItem: ProvenanceWorkItemRecord?

    /// Creates a current-context session row.
    public init(
        session: ProvenanceSessionRecord,
        contribution: ProvenanceContributionRecord?,
        workItem: ProvenanceWorkItemRecord?
    ) {
        self.session = session
        self.contribution = contribution
        self.workItem = workItem
    }
}
