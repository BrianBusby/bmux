import Foundation

/// One ordered step inside an observed coding-agent plan update.
public struct ProvenanceCodingAgentPlanStepRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable step identifier within the plan update.
    public let id: String

    /// Zero-based plan step order.
    public let order: Int

    /// Provider-emitted step text.
    public let text: String

    /// Provider-emitted status, such as `pending`, `in_progress`, or `completed`.
    public let status: String

    /// Creates a plan step record.
    public init(id: String, order: Int, text: String, status: String) {
        self.id = id
        self.order = order
        self.text = text
        self.status = status
    }
}
