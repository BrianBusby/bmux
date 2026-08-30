import Foundation

/// Provider-independent reported state for a coding-agent approach change.
public enum ProvenanceCodingAgentApproachChangeState: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Accepted evidence reports that a prior approach was replaced by another approach.
    case reportedReplaced = "reported_replaced"

    /// Accepted evidence reports that a prior approach was abandoned without proving failure.
    case reportedAbandoned = "reported_abandoned"

    /// Accepted evidence reports that a prior approach was deferred.
    case reportedDeferred = "reported_deferred"

    /// Accepted evidence reports that a prior approach failed.
    case reportedFailed = "reported_failed"

    /// Accepted evidence is insufficient for a supported approach-change state.
    case unknown
}
