/// Bounded provider error details carried by execution telemetry.
public struct ExecutionTelemetryErrorInfo: Sendable, Equatable, Decodable {
    /// Human-readable error summary.
    public let message: String

    /// Provider error code, when available.
    public let code: String?
}
