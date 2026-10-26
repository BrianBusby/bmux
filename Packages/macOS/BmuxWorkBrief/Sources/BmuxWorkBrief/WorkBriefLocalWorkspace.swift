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
    /// PE-observed pull-request status, when present.
    public let pullRequestStatus: String?
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
    /// - Parameters:
    ///   - id: The restart-stable workspace identity.
    ///   - runtimeID: The current runtime identity used for validated navigation.
    ///   - title: The current bmux workspace title.
    ///   - repository: An observed repository label, when known.
    ///   - branch: An observed branch name, when known.
    ///   - tickets: Explicit source links to tickets.
    ///   - pullRequest: An explicit source link to a pull request.
    ///   - pullRequestStatus: PE-observed pull-request status, when present.
    ///   - status: Verified local activity state.
    ///   - surfaceID: An accepted PE surface association, when known.
    ///   - lastActivityAt: Latest accepted activity time, when known.
    ///   - checkedAt: The time these source facts were checked.
    ///   - evidence: Bounded references supporting the displayed facts.
    public init(id: UUID, runtimeID: UUID, title: String, repository: String?, branch: String?,
                tickets: [WorkBriefLink], pullRequest: WorkBriefLink?, status: WorkBriefLocalStatus,
                pullRequestStatus: String? = nil, surfaceID: String?, lastActivityAt: Date?, checkedAt: Date,
                evidence: [WorkBriefEvidence]) {
        self.id = id
        self.runtimeID = runtimeID
        self.title = title
        self.repository = repository
        self.branch = branch
        self.tickets = tickets
        self.pullRequest = pullRequest
        self.pullRequestStatus = pullRequestStatus
        self.status = status
        self.surfaceID = surfaceID
        self.lastActivityAt = lastActivityAt
        self.checkedAt = checkedAt
        self.evidence = evidence
    }
}
