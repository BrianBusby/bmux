import Foundation

/// Honest freshness state for a source, including an unconfigured source.
public struct WorkBriefSourceHealth: Equatable, Sendable {
    /// Current source state.
    public enum State: Equatable, Sendable {
        /// The source read completed with available facts.
        case available
        /// Some facts remain unavailable after the source read.
        case partial
        /// The source read failed.
        case failed
        /// The source has not been connected to this brief.
        case notConfigured
    }
    /// Current state.
    public let state: State
    /// Last successful or attempted check.
    public let checkedAt: Date?
    /// Stable reason code suitable for support diagnostics.
    public let reasonCode: String?

    /// Creates a source-health value.
    /// - Parameters:
    ///   - state: The current source state.
    ///   - checkedAt: The time of the last attempted or successful check.
    ///   - reasonCode: A stable diagnostic code without private source content.
    public init(state: State, checkedAt: Date?, reasonCode: String? = nil) {
        self.state = state
        self.checkedAt = checkedAt
        self.reasonCode = reasonCode
    }
}
