import Foundation

/// Provider-independent reported state for a coding-agent blocker.
public enum ProvenanceCodingAgentBlockerState: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Accepted evidence reports that the condition is currently blocking progress.
    case reportedOpen = "reported_open"

    /// Accepted evidence reports that the condition was cleared.
    case reportedCleared = "reported_cleared"

    /// Accepted evidence reports that work can proceed by bypassing the condition.
    case reportedBypassed = "reported_bypassed"

    /// Accepted evidence reports that the condition no longer applies.
    case reportedNoLongerApplies = "reported_no_longer_applies"

    /// Accepted evidence is insufficient for a supported blocker state.
    case unknown
}
