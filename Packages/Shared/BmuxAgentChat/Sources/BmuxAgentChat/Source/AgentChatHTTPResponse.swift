import Foundation

/// Minimal HTTP response value used by package-level sidecar clients.
public struct AgentChatHTTPResponse: Sendable, Equatable {
    /// Response body data.
    public let data: Data

    /// HTTP status code.
    public let statusCode: Int

    /// Creates an HTTP response value.
    ///
    /// - Parameters:
    ///   - data: Response body data.
    ///   - statusCode: HTTP status code.
    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}
