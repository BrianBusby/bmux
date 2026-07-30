import Foundation

/// Native read client for bounded agent-chat sidecar session summaries.
public struct AgentChatSessionListClient: Sendable {
    /// Base URL of the agent-chat sidecar.
    public let baseURL: URL

    private let loader: any AgentChatHTTPLoading
    private let coding: ChatWireCoding

    /// Creates a sidecar session-list client.
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

    /// Reads bounded sidecar session summaries.
    ///
    /// - Returns: Sidecar session summaries in server order.
    /// - Throws: ``ExecutionTelemetryLiveProjectionClientError`` for endpoint
    ///   or HTTP response failures, plus transport and decoding errors.
    public func list() async throws -> [AgentChatSessionSummary] {
        let endpoint = try sessionsURL()
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
        return try coding.decode([AgentChatSessionSummary].self, from: response.data)
    }

    /// Builds the sidecar sessions endpoint URL.
    ///
    /// - Returns: The sidecar sessions endpoint URL.
    /// - Throws: ``ExecutionTelemetryLiveProjectionClientError/invalidEndpoint``
    ///   when the URL cannot be built.
    public func sessionsURL() throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidEndpoint
        }
        components.path = "/api/sessions"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidEndpoint
        }
        return url
    }
}
