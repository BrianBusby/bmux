public import Foundation

/// Evidence-backed work-item or provenance reference detected for a thread.
public struct ContextEfficiencyWorkItemReferenceRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable reference fact identifier.
    public var id: String
    /// Thread that owns the reference fact.
    public var threadID: String
    /// Kind of work-item reference.
    public var kind: ContextEfficiencyWorkItemReferenceKind
    /// Normalized durable reference, such as `github:owner/repo#123`.
    public var reference: String
    /// GitHub `owner/name` slug when evidence supplied one.
    public var repositorySlug: String?
    /// Numeric PR or issue identifier when evidence supplied one.
    public var number: Int?
    /// URL string when the reference appeared as a URL.
    public var urlString: String?
    /// Branch name when the reference came from branch evidence.
    public var branchName: String?
    /// Ticket key when evidence supplied one.
    public var ticketKey: String?
    /// Evidence source class that produced this fact.
    public var sourceKind: ContextEfficiencyWorkItemReferenceSource
    /// Confidence label for this reference fact.
    public var confidence: ContextEfficiencyWorkItemReferenceConfidence
    /// Source path for cleanup and recovery.
    public var sourcePath: String
    /// Precise rollout source location when the fact came from a rollout line.
    public var sourceReference: ContextEfficiencySourceReference?
    /// Event timestamp when the source supplied one.
    public var observedAt: Date?

    /// Creates a work-item reference fact.
    public init(
        id: String,
        threadID: String,
        kind: ContextEfficiencyWorkItemReferenceKind,
        reference: String,
        repositorySlug: String?,
        number: Int?,
        urlString: String?,
        branchName: String?,
        ticketKey: String?,
        sourceKind: ContextEfficiencyWorkItemReferenceSource,
        confidence: ContextEfficiencyWorkItemReferenceConfidence,
        sourcePath: String,
        sourceReference: ContextEfficiencySourceReference?,
        observedAt: Date?
    ) {
        self.id = id
        self.threadID = threadID
        self.kind = kind
        self.reference = reference
        self.repositorySlug = repositorySlug
        self.number = number
        self.urlString = urlString
        self.branchName = branchName
        self.ticketKey = ticketKey
        self.sourceKind = sourceKind
        self.confidence = confidence
        self.sourcePath = sourcePath
        self.sourceReference = sourceReference
        self.observedAt = observedAt
    }
}
