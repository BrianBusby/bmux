/// Canonical event for file changes observed during or after a turn.
public struct ExecutionTelemetryFilesChangedEvent: Sendable, Equatable, Decodable {
    /// Source that detected the file changes.
    public let source: String

    /// Changed file summaries.
    public let files: [ExecutionTelemetryChangedFile]
}
