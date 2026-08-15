/// One ordered step inside a canonical provider plan update.
public struct ExecutionTelemetryPlanStep: Sendable, Equatable, Decodable {
    /// Provider-emitted step text.
    public let text: String

    /// Provider-emitted step status.
    public let status: String
}
