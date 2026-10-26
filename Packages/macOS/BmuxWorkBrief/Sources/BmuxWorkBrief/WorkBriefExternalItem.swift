import Foundation

/// A bounded, source-backed work item acquired from an external provider.
public struct WorkBriefExternalItem: Equatable, Sendable, Identifiable {
    /// Provider-qualified stable ID, such as `linear:<issue-id>`.
    public let id: String
    /// Provider that owns this fact.
    public let source: WorkBriefSource
    /// Short provider title; descriptions and comments are excluded.
    public let title: String
    /// Provider's own HTTPS URL.
    public let url: URL
    /// Provider's short issue or pull-request reference.
    public let reference: String
    /// Explicitly supplied repository identity, when available.
    public let repository: String?
    /// Provider-supplied owner display name, when available.
    public let owner: String?
    /// Provider-supplied status display name.
    public let status: String
    /// Provider-supplied last update time.
    public let updatedAt: Date
    /// Time this fact was last checked.
    public let checkedAt: Date
    /// Deterministic classification from provider fields.
    public let disposition: Disposition
    /// Explicit relationships and source references.
    public let evidence: [WorkBriefEvidence]

    /// What the provider facts say about this item in the brief.
    public enum Disposition: Equatable, Sendable {
        /// Provider facts require a decision or review by the user.
        case needsAttention
        /// Provider facts describe active work without a verified wait.
        case inProgress
        /// Provider facts explicitly show a requested review from another actor.
        case waitingOn
    }

    /// Creates an immutable external fact. The producer validates URLs and caps strings.
    /// - Parameters:
    ///   - id: Provider-qualified stable identity.
    ///   - source: Provider that supplied the fact.
    ///   - title: Short provider title.
    ///   - url: Validated HTTPS source URL.
    ///   - reference: Short ticket or PR reference.
    ///   - repository: Explicit repository identity, if supplied.
    ///   - owner: Provider-supplied owner, if available.
    ///   - status: Provider-supplied status.
    ///   - updatedAt: Provider update time.
    ///   - checkedAt: Latest successful check time.
    ///   - disposition: Deterministic classification.
    ///   - evidence: Source references, capped at 12.
    public init(id: String, source: WorkBriefSource, title: String, url: URL,
                reference: String, repository: String?, owner: String?, status: String,
                updatedAt: Date, checkedAt: Date, disposition: Disposition,
                evidence: [WorkBriefEvidence]) {
        self.id = id
        self.source = source
        self.title = title
        self.url = url
        self.reference = reference
        self.repository = repository
        self.owner = owner
        self.status = status
        self.updatedAt = updatedAt
        self.checkedAt = checkedAt
        self.disposition = disposition
        self.evidence = Array(evidence.prefix(12))
    }
}
