/// Bounded files-changed state from the live execution telemetry projection.
public struct ExecutionTelemetryLiveFilesChangedSummary: Sendable, Equatable, Codable {
    /// Whether the projection has observed file changes.
    public let hasChanges: Bool

    /// Count of unique changed file paths observed by the sidecar.
    public let count: Int

    /// Creates a bounded files-changed summary.
    public init(hasChanges: Bool, count: Int) {
        self.hasChanges = hasChanges
        self.count = count
    }
}
