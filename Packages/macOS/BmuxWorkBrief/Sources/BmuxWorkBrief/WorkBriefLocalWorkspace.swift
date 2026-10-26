import Foundation

/// One open bmux workspace joined to accepted, bounded display facts.
public struct WorkBriefLocalWorkspace: Equatable, Sendable, Identifiable {
    /// Restart-stable workspace identity.
    public let id: UUID
    /// Current runtime identity, validated again before navigation.
    public let runtimeID: UUID
    /// Current workspace title.
    public let title: String
    /// Observed repository label, when available.
    public let repository: String?
    /// Observed branch, when available.
    public let branch: String?
    /// Explicit ticket links.
    public let tickets: [WorkBriefLink]
    /// Explicit pull request link.
    public let pullRequest: WorkBriefLink?
    /// Verified local activity.
    public let status: WorkBriefLocalStatus
    /// PE-associated surface ID, when known.
    public let surfaceID: String?
    /// Latest accepted activity timestamp.
    public let lastActivityAt: Date?
    /// The time source facts were checked.
    public let checkedAt: Date
    /// Evidence behind displayed relationships.
    public let evidence: [WorkBriefEvidence]

    /// Creates one immutable local work item.
    public init(id: UUID, runtimeID: UUID, title: String, repository: String?, branch: String?,
                tickets: [WorkBriefLink], pullRequest: WorkBriefLink?, status: WorkBriefLocalStatus,
                surfaceID: String?, lastActivityAt: Date?, checkedAt: Date,
                evidence: [WorkBriefEvidence]) {
        self.id = id
        self.runtimeID = runtimeID
        self.title = title
        self.repository = repository
        self.branch = branch
        self.tickets = tickets
        self.pullRequest = pullRequest
        self.status = status
        self.surfaceID = surfaceID
        self.lastActivityAt = lastActivityAt
        self.checkedAt = checkedAt
        self.evidence = evidence
    }
}
