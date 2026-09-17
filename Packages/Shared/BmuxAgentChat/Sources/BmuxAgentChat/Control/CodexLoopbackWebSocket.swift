import Foundation

/// Authenticated local WebSocket transport. Inject a transport instead in tests.
public actor CodexLoopbackWebSocket: CodexRPCTransport {
    private let session: URLSession
    private let task: URLSessionWebSocketTask

    public init(endpoint: URL, token: String) throws {
        guard endpoint.scheme == "ws", endpoint.host == "127.0.0.1",
              endpoint.port != nil, endpoint.user == nil, endpoint.password == nil,
              endpoint.query == nil, !token.isEmpty else {
            throw URLError(.unsupportedURL)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        task = session.webSocketTask(with: request)
        task.maximumMessageSize = 8 * 1024 * 1024
        task.resume()
    }

    public func send(_ message: Data) async throws {
        try await task.send(.string(String(decoding: message, as: UTF8.self)))
    }

    public func receive() async throws -> Data {
        switch try await task.receive() {
        case .data(let data): return data
        case .string(let text): return Data(text.utf8)
        @unknown default: throw URLError(.cannotDecodeContentData)
        }
    }

    public func close() {
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }
}
