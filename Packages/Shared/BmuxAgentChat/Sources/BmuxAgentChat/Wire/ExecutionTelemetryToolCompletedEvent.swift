/// Canonical event for a completed provider tool operation.
public struct ExecutionTelemetryToolCompletedEvent: Sendable, Equatable, Decodable {
    /// Provider operation id for the tool.
    public let operationID: String

    /// Provider-neutral tool kind, when known.
    public let toolKind: String?

    /// Provider-neutral tool name, when known.
    public let name: String?

    /// Completion status.
    public let status: String

    /// Bounded output summary, when policy permits it.
    public let outputSummary: String?

    /// Process exit code, when available.
    public let exitCode: Int?

    /// Operation duration in milliseconds, when available.
    public let durationMs: Int?

    /// Completion timestamp in Unix epoch milliseconds, when available.
    public let completedAtMs: Int?

    private enum CodingKeys: String, CodingKey {
        case operationID = "operationId"
        case toolKind
        case name
        case status
        case outputSummary
        case exitCode
        case durationMs
        case completedAtMs
    }
}
