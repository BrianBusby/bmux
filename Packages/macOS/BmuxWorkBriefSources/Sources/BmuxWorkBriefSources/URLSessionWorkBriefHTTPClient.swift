import Foundation

/// Ephemeral URLSession transport without persistent response caching.
public struct URLSessionWorkBriefHTTPClient: WorkBriefHTTPClient {
    private let session: URLSession

    /// Creates a transport with an injected session for testing or app composition.
    public init(session: URLSession) {
        self.session = session
    }

    /// Reads one provider response.
    public func response(for request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
