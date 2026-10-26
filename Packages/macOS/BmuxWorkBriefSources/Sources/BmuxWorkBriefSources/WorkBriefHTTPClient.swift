import Foundation

/// Injected transport for bounded provider reads.
public protocol WorkBriefHTTPClient: Sendable {
    /// Returns response bytes and HTTP status for one request.
    /// - Parameter request: The provider request to perform.
    /// - Returns: Response bytes and HTTP status.
    /// - Throws: A transport or response-size error.
    func response(for request: URLRequest) async throws -> (Data, Int)
}
