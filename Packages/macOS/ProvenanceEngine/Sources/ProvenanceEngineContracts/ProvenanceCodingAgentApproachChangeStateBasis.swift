import Foundation

/// Evidence basis used to assign a coding-agent approach-change state.
public enum ProvenanceCodingAgentApproachChangeStateBasis: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// State is grounded in an explicit visible agent approach-change statement.
    case visibleAgentStatement = "visible_agent_statement"

    /// No supported state evidence was available.
    case unavailable

    /// The approach change came from an older payload that did not record state basis.
    case legacyPayload = "legacy_payload"
}
