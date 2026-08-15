/// Canonical event for a provider plan update.
public struct ExecutionTelemetryPlanUpdatedEvent: Sendable, Equatable, Decodable {
    /// Provider explanation for the plan update, when available.
    public let explanation: String?

    /// Ordered provider-emitted plan steps.
    public let steps: [ExecutionTelemetryPlanStep]
}
