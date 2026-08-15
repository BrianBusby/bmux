/// Canonical event for a started provider tool operation.
public struct ExecutionTelemetryToolStartedEvent: Sendable, Equatable, Decodable {
    /// Provider operation id for the tool.
    public let operationID: String

    /// Provider-neutral tool kind.
    public let toolKind: String

    /// Provider-neutral tool name.
    public let name: String

    /// Bounded input summary, when policy permits it.
    public let inputSummary: String?

    /// Working directory for the tool operation, when known.
    public let cwd: String?

    /// Start timestamp in Unix epoch milliseconds, when available.
    public let startedAtMs: Int?

    private enum CodingKeys: String, CodingKey {
        case operationID = "operationId"
        case toolKind
        case name
        case inputSummary
        case cwd
        case startedAtMs
    }
}
