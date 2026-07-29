/// REST payload returned by the sidecar live execution telemetry read endpoint.
public struct ExecutionTelemetryLiveProjectionReadPayload: Sendable, Equatable, Codable {
    /// bmux sidecar session id requested by the caller.
    public let sessionID: String

    /// Latest bounded snapshot, or `nil` before canonical telemetry exists.
    public let snapshot: ExecutionTelemetryLiveProjectionSnapshot?

    /// Creates a live projection read payload.
    ///
    /// - Parameters:
    ///   - sessionID: bmux sidecar session id requested by the caller.
    ///   - snapshot: Latest bounded snapshot, or `nil` before telemetry exists.
    public init(sessionID: String, snapshot: ExecutionTelemetryLiveProjectionSnapshot?) {
        self.sessionID = sessionID
        self.snapshot = snapshot
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case snapshot
    }
}
