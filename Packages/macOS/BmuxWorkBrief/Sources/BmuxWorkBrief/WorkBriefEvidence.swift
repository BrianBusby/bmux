import Foundation

/// A source-backed explanation for one displayed fact or relationship.
public struct WorkBriefEvidence: Equatable, Sendable, Identifiable {
    /// Stable identifier within the brief.
    public let id: String
    /// The source that observed the fact.
    public let source: WorkBriefSource
    /// Short source field name, without private payload text.
    public let field: String
    /// Whether the relationship is directly observed or suggested.
    public let isObserved: Bool
    /// When the source last checked this fact.
    public let checkedAt: Date
    /// A source URL when one was supplied explicitly.
    public let url: URL?
    /// Durable PE event identity when the projection supplies it.
    public let referenceID: String?

    /// Creates a bounded evidence reference.
    public init(id: String, source: WorkBriefSource, field: String,
                isObserved: Bool, checkedAt: Date, url: URL? = nil, referenceID: String? = nil) {
        self.id = id
        self.source = source
        self.field = field
        self.isObserved = isObserved
        self.checkedAt = checkedAt
        self.url = url
        self.referenceID = referenceID
    }
}
