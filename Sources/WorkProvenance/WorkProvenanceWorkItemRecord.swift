import Foundation

/// Current-state projection for a durable work item.
struct WorkProvenanceWorkItemRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable work item identifier.
    let id: String

    /// Human-readable durable goal title.
    let title: String

    /// Lifecycle status such as `proposed`, `active`, `completed`, or `superseded`.
    let status: String

    /// First observed time.
    let createdAt: Date

    /// Last projection update time.
    let updatedAt: Date

    /// Creates a work item projection record.
    init(id: String, title: String, status: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
