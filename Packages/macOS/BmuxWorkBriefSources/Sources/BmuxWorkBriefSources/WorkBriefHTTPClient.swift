import Foundation

/// Injected transport for bounded provider reads.
public protocol WorkBriefHTTPClient: Sendable {
    /// Returns response bytes and HTTP status for one request.
    func response(for request: URLRequest) async throws -> (Data, Int)
}
