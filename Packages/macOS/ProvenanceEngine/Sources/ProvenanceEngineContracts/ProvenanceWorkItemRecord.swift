import Foundation

/// Current-state projection for a durable work item.
public struct ProvenanceWorkItemRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable work item identifier.
    public let id: String

    /// Human-readable durable goal title.
    public let title: String

    /// Lifecycle status such as `proposed`, `active`, `completed`, or `superseded`.
    public let status: String

    /// First observed time.
    public let createdAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a work item projection record.
    public init(id: String, title: String, status: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
