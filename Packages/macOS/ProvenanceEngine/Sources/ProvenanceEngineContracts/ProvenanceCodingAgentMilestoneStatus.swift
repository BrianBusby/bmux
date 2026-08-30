import Foundation

/// Provider-independent reported work state for a coding-agent milestone.
public enum ProvenanceCodingAgentMilestoneStatus: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// The provider reported planned or pending work that has not started.
    case planned

    /// The provider reported the milestone currently receiving work.
    case active

    /// The provider reported the milestone complete without proving validation, merge, or acceptance.
    case completed

    /// The provider supplied a status PE cannot safely normalize.
    case unknown
}
