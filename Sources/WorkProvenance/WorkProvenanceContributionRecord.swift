import Foundation

/// Current-state projection for one session's contribution to one work item.
struct WorkProvenanceContributionRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable contribution identifier.
    let id: String

    /// Native agent session identifier.
    let sessionID: String

    /// Worktree identifier.
    let worktreeID: String

    /// Work item identifier.
    let workItemID: String

    /// Agent-declared intent, when available.
    let declaredIntent: String?

    /// Expected file or symbol scope declared for this contribution.
    let expectedScope: [String]

    /// Lifecycle status such as `active`, `completed`, or `interrupted`.
    let status: String

    /// Contribution start time.
    let startedAt: Date

    /// Contribution end time, when closed.
    let endedAt: Date?

    /// Confidence in the work-item assignment.
    let assignmentConfidence: WorkProvenanceConfidence

    /// Last projection update time.
    let updatedAt: Date

    /// Creates a contribution projection record.
    init(
        id: String,
        sessionID: String,
        worktreeID: String,
        workItemID: String,
        declaredIntent: String? = nil,
        expectedScope: [String] = [],
        status: String,
        startedAt: Date,
        endedAt: Date? = nil,
        assignmentConfidence: WorkProvenanceConfidence,
        updatedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.worktreeID = worktreeID
        self.workItemID = workItemID
        self.declaredIntent = declaredIntent
        self.expectedScope = expectedScope
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.assignmentConfidence = assignmentConfidence
        self.updatedAt = updatedAt
    }
}
