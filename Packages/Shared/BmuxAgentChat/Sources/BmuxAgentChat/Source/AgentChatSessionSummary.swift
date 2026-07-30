import Foundation

/// Bounded summary for one agent-chat sidecar session.
public struct AgentChatSessionSummary: Codable, Equatable, Sendable {
    /// bmux sidecar session id.
    public let id: String

    /// Provider kind, such as `codex` or `claude`.
    public let provider: String

    /// Working directory selected for the sidecar session.
    public let cwd: String

    /// Sidecar session status.
    public let status: String

    /// Sidecar creation time in Unix epoch milliseconds.
    public let createdAt: Double

    /// Creates a bounded sidecar session summary.
    ///
    /// - Parameters:
    ///   - id: bmux sidecar session id.
    ///   - provider: Provider kind.
    ///   - cwd: Session working directory.
    ///   - status: Sidecar session status.
    ///   - createdAt: Sidecar creation time in Unix epoch milliseconds.
    public init(
        id: String,
        provider: String,
        cwd: String,
        status: String,
        createdAt: Double
    ) {
        self.id = id
        self.provider = provider
        self.cwd = cwd
        self.status = status
        self.createdAt = createdAt
    }
}
