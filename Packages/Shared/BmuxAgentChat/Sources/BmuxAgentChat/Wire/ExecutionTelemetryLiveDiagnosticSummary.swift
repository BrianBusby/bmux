/// A bounded diagnostic summary from the live execution telemetry projection.
public struct ExecutionTelemetryLiveDiagnosticSummary: Sendable, Equatable, Codable {
    /// Diagnostic severity.
    public let level: String

    /// Bounded provider-neutral diagnostic message.
    public let message: String

    /// Stable diagnostic code, when available.
    public let code: String?

    /// Sidecar capture timestamp, in Unix epoch milliseconds, for this diagnostic.
    public let observedAtMs: Int

    /// Creates a diagnostic summary.
    public init(level: String, message: String, code: String? = nil, observedAtMs: Int) {
        self.level = level
        self.message = message
        self.code = code
        self.observedAtMs = observedAtMs
    }
}
