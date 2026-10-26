import Foundation

/// Honest freshness state for a source, including an unconfigured source.
public struct WorkBriefSourceHealth: Equatable, Sendable {
    /// Current source state.
    public enum State: Equatable, Sendable { case available, partial, failed, notConfigured }
    /// Current state.
    public let state: State
    /// Last successful or attempted check.
    public let checkedAt: Date?
    /// Stable reason code suitable for support diagnostics.
    public let reasonCode: String?

    /// Creates a source-health value.
    public init(state: State, checkedAt: Date?, reasonCode: String? = nil) {
        self.state = state
        self.checkedAt = checkedAt
        self.reasonCode = reasonCode
    }
}
