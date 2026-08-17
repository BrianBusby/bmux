import Foundation

/// Current-state projection for one session's contribution to one work item.
public struct ProvenanceContributionRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable contribution identifier.
    public let id: String

    /// Native agent session identifier.
    public let sessionID: String

    /// Worktree identifier.
    public let worktreeID: String

    /// Work item identifier.
    public let workItemID: String

    /// Agent-declared intent, when available.
    public let declaredIntent: String?

    /// Expected file or symbol scope declared for this contribution.
    public let expectedScope: [String]

    /// Lifecycle status such as `active`, `completed`, or `interrupted`.
    public let status: String

    /// Contribution start time.
    public let startedAt: Date

    /// Contribution end time, when closed.
    public let endedAt: Date?

    /// Confidence in the work-item assignment.
    public let assignmentConfidence: ProvenanceConfidence

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a contribution projection record.
    public init(
        id: String,
        sessionID: String,
        worktreeID: String,
        workItemID: String,
        declaredIntent: String? = nil,
        expectedScope: [String] = [],
        status: String,
        startedAt: Date,
        endedAt: Date? = nil,
        assignmentConfidence: ProvenanceConfidence,
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
