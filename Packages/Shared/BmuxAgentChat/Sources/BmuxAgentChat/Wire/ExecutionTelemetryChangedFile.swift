/// One repository-relative file path observed in a telemetry files-changed event.
public struct ExecutionTelemetryChangedFile: Sendable, Equatable, Decodable {
    /// Repository-relative path that changed.
    public let path: String

    /// Provider or git status label for the path.
    public let status: String

    /// Added line count, when known.
    public let additions: Int?

    /// Deleted line count, when known.
    public let deletions: Int?

    /// Bounded producer summary for the file change, when policy permits it.
    public let summary: String?
}
