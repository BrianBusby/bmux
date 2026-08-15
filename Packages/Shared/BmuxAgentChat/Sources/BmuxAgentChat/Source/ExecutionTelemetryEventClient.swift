import Foundation

/// Native cursor client for bounded canonical execution telemetry envelopes.
public struct ExecutionTelemetryEventClient: Sendable {
    /// Base URL of the agent-chat sidecar.
    public let baseURL: URL

    private let loader: any AgentChatHTTPLoading
    private let coding: ChatWireCoding

    /// Creates an execution telemetry event client.
    public init(
        baseURL: URL,
        loader: any AgentChatHTTPLoading = URLSession.shared,
        coding: ChatWireCoding = ChatWireCoding()
    ) {
        self.baseURL = baseURL
        self.loader = loader
        self.coding = coding
    }

    /// Reads canonical telemetry envelopes after an exclusive sequence cursor.
    public func read(
        sessionID: String,
        afterSequence: Int = 0,
        limit: Int = 200
    ) async throws -> ExecutionTelemetryEventReadPayload {
        let endpoint = try eventsURL(sessionID: sessionID, afterSequence: afterSequence, limit: limit)
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
        return try coding.decode(ExecutionTelemetryEventReadPayload.self, from: response.data)
    }

    /// Builds the sidecar telemetry event endpoint URL for a session cursor.
    public func eventsURL(
        sessionID: String,
        afterSequence: Int = 0,
        limit: Int = 200
    ) throws -> URL {
        guard !sessionID.isEmpty, !sessionID.contains("/") else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidSessionID
        }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidEndpoint
        }
        components.path = "/api/sessions/\(sessionID)/execution-telemetry/events"
        components.queryItems = [
            URLQueryItem(name: "afterSequence", value: String(max(0, afterSequence))),
            URLQueryItem(name: "limit", value: String(max(0, limit))),
        ]
        components.fragment = nil
        guard let url = components.url else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidEndpoint
        }
        return url
    }
}
