import Foundation

/// Current-state projection for one validation command or check.
public struct ProvenanceValidationRunRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable validation-run identifier.
    public let id: String

    /// Checkpoint identifier, when the run belongs to a checkpoint.
    public let checkpointID: String?

    /// Contribution identifier, when attributed.
    public let contributionID: String?

    /// Command or validation label.
    public let command: String

    /// Validation status such as `passed`, `failed`, `running`, or `cancelled`.
    public let status: String

    /// Short validation summary.
    public let summary: String?

    /// Validation start time.
    public let startedAt: Date?

    /// Validation end time, when known.
    public let endedAt: Date?

    /// Creates a validation-run projection record.
    public init(
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
