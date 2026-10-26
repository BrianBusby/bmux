import Foundation

/// Ephemeral URLSession transport without persistent response caching.
public struct URLSessionWorkBriefHTTPClient: WorkBriefHTTPClient {
    private let session: URLSession
    private let maximumResponseBytes = 2_000_000

    /// Creates a transport with an injected session for testing or app composition.
    /// - Parameter session: The URLSession used for read-only provider requests.
    public init(session: URLSession) {
        self.session = session
    }

    /// Streams one provider response, rejecting payloads beyond the bounded fact budget.
    /// - Parameter request: A provider request with the caller's timeout and authorization.
    /// - Returns: At most 2,000,000 bytes and the HTTP response status.
    /// - Throws: A transport error or an error when the response exceeds the byte cap.
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
