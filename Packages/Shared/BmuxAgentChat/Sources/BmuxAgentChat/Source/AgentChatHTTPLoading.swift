import Foundation

/// Async HTTP loading seam for package-level sidecar clients.
public protocol AgentChatHTTPLoading: Sendable {
    /// Loads a URL request and returns the response body plus status code.
    ///
    /// - Parameter request: The request to load.
    /// - Returns: Response body data and HTTP status code.
    /// - Throws: Transport errors surfaced by the loader.
    func load(_ request: URLRequest) async throws -> AgentChatHTTPResponse
}

extension URLSession: AgentChatHTTPLoading {
    public func load(_ request: URLRequest) async throws -> AgentChatHTTPResponse {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExecutionTelemetryLiveProjectionClientError.invalidResponse
        }
        return AgentChatHTTPResponse(data: data, statusCode: httpResponse.statusCode)
    }
}
