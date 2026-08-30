import Foundation

/// Completeness of detailed factual source history available to a semantic rule.
public enum ProvenanceCodingAgentSemanticSourceHistoryState: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Detailed source history covers all observed turns known to the factual projection.
    case complete

    /// Detailed source history is bounded and may omit older turn-level statement evidence.
    case partial
}
