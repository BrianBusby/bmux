import Foundation
import Network

/// Async boundary around Network's callback API. One reader and one writer may
/// operate concurrently; reads are exact and bounded, with TCP backpressure.
struct CodexRelayByteStream: Sendable {
    let connection: NWConnection

    func read(_ count: Int) async throws -> Data {
        var output = Data()
        while output.count < count {
            let bytes = try await receive(maximum: count - output.count)
            guard !bytes.isEmpty else { throw URLError(.networkConnectionLost) }
            output.append(bytes)
        }
        return output
    }

    func receive(maximum: Int = 64 * 1024) async throws -> Data {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maximum) { data, _, _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data ?? Data()) }
            }
        }
    }

    func send(_ data: Data) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    func upgradeHeader() async throws -> Data {
        var header = Data()
        // Upgrade headers are small; exact reads leave any coalesced frame bytes
        // on the socket, so the streaming parser needs no growing read buffer.
        while header.count < 16 * 1024 {
            header.append(try await read(1))
            if header.suffix(4) == Data([13, 10, 13, 10]) { return header }
        }
        throw URLError(.dataLengthExceedsMaximum)
    }
}
