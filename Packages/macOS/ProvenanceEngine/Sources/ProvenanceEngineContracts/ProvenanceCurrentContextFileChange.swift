import Foundation

/// File-change row returned by a current-context query.
public struct ProvenanceCurrentContextFileChange: Codable, Equatable, Sendable {
    /// File-change projection.
    public let fileChange: ProvenanceFileChangeRecord

    /// Change set containing the file change, when available.
    public let changeSet: ProvenanceChangeSetRecord?

    /// Contribution linked to the change, when available.
    public let contribution: ProvenanceContributionRecord?

    /// Session linked to the contribution, when available.
    public let session: ProvenanceSessionRecord?

    /// Creates a current-context file-change row.
    public init(
        fileChange: ProvenanceFileChangeRecord,
        changeSet: ProvenanceChangeSetRecord?,
        contribution: ProvenanceContributionRecord?,
        session: ProvenanceSessionRecord?
    ) {
        self.fileChange = fileChange
        self.changeSet = changeSet
        self.contribution = contribution
        self.session = session
    }
}
