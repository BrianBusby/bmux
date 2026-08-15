/// Canonical event for submitted user prompt text.
public struct ExecutionTelemetryPromptSubmittedEvent: Sendable, Equatable, Decodable {
    /// Submitted prompt text.
    public let text: String
}
