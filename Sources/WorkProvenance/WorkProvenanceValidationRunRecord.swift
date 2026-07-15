import Foundation

/// Current-state projection for one validation command or check.
struct WorkProvenanceValidationRunRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable validation-run identifier.
    let id: String

    /// Checkpoint identifier, when the run belongs to a checkpoint.
    let checkpointID: String?

    /// Contribution identifier, when attributed.
    let contributionID: String?

    /// Command or validation label.
    let command: String

    /// Validation status such as `passed`, `failed`, `running`, or `cancelled`.
    let status: String

    /// Short validation summary.
    let summary: String?

    /// Validation start time.
    let startedAt: Date?

    /// Validation end time.
    let endedAt: Date?

    /// Creates a validation-run projection record.
    init(
        id: String,
        checkpointID: String? = nil,
        contributionID: String? = nil,
        command: String,
        status: String,
        summary: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.checkpointID = checkpointID
        self.contributionID = contributionID
        self.command = command
        self.status = status
        self.summary = summary
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
