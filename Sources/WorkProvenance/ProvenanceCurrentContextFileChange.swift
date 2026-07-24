import Foundation

/// File-change row returned by a current-context query.
struct ProvenanceCurrentContextFileChange: Codable, Equatable, Sendable {
    /// File-change projection.
    let fileChange: WorkProvenanceFileChangeRecord

    /// Change set containing the file change, when available.
    let changeSet: WorkProvenanceChangeSetRecord?

    /// Contribution linked to the change, when available.
    let contribution: WorkProvenanceContributionRecord?

    /// Session linked to the contribution, when available.
    let session: WorkProvenanceSessionRecord?

    /// Creates a current-context file-change row.
    init(
        fileChange: WorkProvenanceFileChangeRecord,
        changeSet: WorkProvenanceChangeSetRecord?,
        contribution: WorkProvenanceContributionRecord?,
        session: WorkProvenanceSessionRecord?
    ) {
        self.fileChange = fileChange
        self.changeSet = changeSet
        self.contribution = contribution
        self.session = session
    }
}
