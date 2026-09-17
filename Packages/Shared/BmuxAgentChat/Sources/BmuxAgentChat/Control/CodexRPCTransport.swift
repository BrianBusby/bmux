import Foundation

/// A single authenticated connection to an existing Codex host. Implementations
/// never start, resume in another process, or terminate the provider.
public protocol CodexRPCTransport: Sendable {
    func send(_ message: Data) async throws
    func receive() async throws -> Data
    func close() async
}
