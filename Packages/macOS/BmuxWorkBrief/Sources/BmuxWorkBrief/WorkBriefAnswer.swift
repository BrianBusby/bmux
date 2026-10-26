import Foundation

/// Source-backed result of a bounded on-demand Work Brief question.
public struct WorkBriefAnswer: Equatable, Sendable {
    /// Supported deterministic question category.
    public enum Kind: Equatable, Sendable {
        /// Verified work requiring attention.
        case needsAttention
        /// Active local and unlinked external work.
        case inProgress
        /// Explicit external review waits.
        case waitingOn
        /// Pull-request links found through an explicit ticket relationship.
        case ticketPullRequest
        /// No source-backed relationship matched the question.
        case noEvidence
        /// The question is outside the available fact model.
        case unsupported
    }

    /// Category used by the view for localized wording.
    public let kind: Kind
    /// Stable local workspace IDs supporting this answer.
    public let localIDs: [UUID]
    /// Stable external item IDs supporting this answer.
    public let externalIDs: [String]
    /// Explicit links supporting a ticket-to-PR answer.
    public let links: [WorkBriefLink]

    /// Creates an answer from source-backed IDs and links.
    public init(kind: Kind, localIDs: [UUID] = [], externalIDs: [String] = [],
                links: [WorkBriefLink] = []) {
        self.kind = kind
        self.localIDs = Array(localIDs.prefix(20))
        self.externalIDs = Array(externalIDs.prefix(20))
        self.links = Array(links.prefix(12))
    }
}
