import Foundation

/// Native read client for the sidecar live execution telemetry projection.
///
/// This client consumes the bounded REST payload from
/// `/api/sessions/:id/execution-telemetry/live`. It intentionally reads the
/// live projection snapshot only; it does not subscribe to WebSocket UI
/// events, persist telemetry, or define the canonical telemetry schema.
public struct ExecutionTelemetryLiveProjectionClient: Sendable {
    /// Base URL of the agent-chat sidecar.
    public let baseURL: URL

    private let loader: any AgentChatHTTPLoading
    private let coding: ChatWireCoding

    /// Creates a live projection read client.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL of the agent-chat sidecar.
    ///   - loader: HTTP loading seam. Defaults to `URLSession.shared`.
    ///   - coding: JSON coding policy for the response body.
    public init(
        baseURL: URL,
        loader: any AgentChatHTTPLoading = URLSession.shared,
        coding: ChatWireCoding = ChatWireCoding()
    ) {
        self.baseURL = baseURL
        self.loader = loader
        self.coding = coding
    }

    /// Reads the latest live execution telemetry projection for a session.
    ///
    /// - Parameter sessionID: bmux sidecar session id.
    /// - Returns: The bounded read payload, with a `nil` snapshot before
    ///   canonical telemetry exists.
    /// - Throws: ``ExecutionTelemetryLiveProjectionClientError`` for endpoint
    ///   or HTTP response failures, plus transport and decoding errors.
    public func read(sessionID: String) async throws -> ExecutionTelemetryLiveProjectionReadPayload {
        let endpoint = try liveProjectionURL(sessionID: sessionID)
        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 5
        )
        request.httpMethod = "GET"
        let response = try await loader.load(request)
        guard (200..<300).contains(response.statusCode) else {
            throw ExecutionTelemetryLiveProjectionClientError.httpStatus(response.statusCode)
        }
        return try coding.decode(ExecutionTelemetryLiveProjectionReadPayload.self, from: response.data)
    }

    /// Builds the live projection endpoint URL for a session.
    ///
    /// - Parameter sessionID: bmux sidecar session id.
    /// - Returns: The sidecar live projection endpoint URL.
    /// - Throws: ``ExecutionTelemetryLiveProjectionClientError/invalidSessionID``
    ///   when the id cannot be represented as a single path segment.
    public func liveProjectionURL(sessionID: String) throws -> URL {
        guard !sessionID.isEmpty, !sessionID.contains("/") else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidSessionID
        }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidEndpoint
        }
        components.path = "/api/sessions/\(sessionID)/execution-telemetry/live"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidEndpoint
        }
        return url
    }
}
