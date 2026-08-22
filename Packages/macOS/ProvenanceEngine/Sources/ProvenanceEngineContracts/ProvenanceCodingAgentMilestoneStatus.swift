import Foundation

/// Provider-independent lifecycle state for a coding-agent milestone.
public enum ProvenanceCodingAgentMilestoneStatus: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Planned or pending work that has not started.
    case planned

    /// The milestone currently receiving work.
    case active

    /// Work the provider reported as complete.
    case completed

    /// The provider supplied a status PE cannot safely normalize.
    case unknown
}
