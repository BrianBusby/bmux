/// Confidence label for a derived context-efficiency attribution.
public enum ContextEfficiencyAttributionConfidence: String, Codable, Equatable, Sendable {
    /// The records share an explicit Codex tool-call identifier.
    case exactToolCallLink = "exact_tool_call_link"
    /// The records are linked only by source order or timestamp.
    case temporalCandidate = "temporal_candidate"
    /// No suitable related record was found.
    case unmatched
}
