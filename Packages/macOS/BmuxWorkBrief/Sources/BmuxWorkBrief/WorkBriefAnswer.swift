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
        /// Ticket and pull-request links observed on the same workspace.
        case ticketPullRequest
        /// No source-backed relationship matched the question.
        case noEvidence
        /// A blocker question lacks a unique visible item reference.
        case needsReference
        /// A named item has no observed waiting reason in available facts.
        case noWaitEvidence
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
    /// - Parameters:
    ///   - kind: Deterministic question category.
    ///   - localIDs: Matching stable workspace IDs, capped at 20.
    ///   - externalIDs: Matching provider item IDs, capped at 20.
    ///   - links: Explicit source URLs, capped at 12.
    public init(kind: Kind, localIDs: [UUID] = [], externalIDs: [String] = [],
                links: [WorkBriefLink] = []) {
        self.kind = kind
        self.localIDs = Array(localIDs.prefix(20))
        self.externalIDs = Array(externalIDs.prefix(20))
        self.links = Array(links.prefix(12))
    }
}
