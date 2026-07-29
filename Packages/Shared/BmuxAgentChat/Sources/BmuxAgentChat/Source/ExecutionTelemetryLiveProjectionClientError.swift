/// Errors returned by ``ExecutionTelemetryLiveProjectionClient``.
public enum ExecutionTelemetryLiveProjectionClientError: Error, Sendable, Equatable {
    /// The requested session id cannot be represented as one URL path segment.
    case invalidSessionID

    /// The sidecar base URL cannot produce the live projection endpoint URL.
    case invalidEndpoint

    /// The loader returned a non-HTTP response.
    case invalidResponse

    /// The sidecar returned a non-2xx HTTP status code.
    case httpStatus(Int)
}
