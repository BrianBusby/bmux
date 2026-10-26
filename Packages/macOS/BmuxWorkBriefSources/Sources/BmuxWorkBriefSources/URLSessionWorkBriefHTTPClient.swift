import Foundation

/// Ephemeral URLSession transport without persistent response caching.
public struct URLSessionWorkBriefHTTPClient: WorkBriefHTTPClient {
    private let session: URLSession
    private let maximumResponseBytes = 2_000_000

    /// Creates a transport with an injected session for testing or app composition.
    public init(session: URLSession) {
        self.session = session
    }

    /// Streams one provider response, rejecting payloads beyond the bounded fact budget.
    public func response(for request: URLRequest) async throws -> (Data, Int) {
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        data.reserveCapacity(64_000)
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else { throw WorkBriefResponseTooLarge() }
            data.append(byte)
        }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

private struct WorkBriefResponseTooLarge: Error {}
