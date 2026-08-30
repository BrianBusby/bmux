import Foundation

/// Evidence basis used to assign a coding-agent blocker state.
public enum ProvenanceCodingAgentBlockerStateBasis: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// State is grounded in an explicit visible agent blocker statement.
    case visibleAgentStatement = "visible_agent_statement"

    /// State is grounded in an explicit visible agent resolution statement.
    case visibleAgentResolutionStatement = "visible_agent_resolution_statement"

    /// No supported state evidence was available.
    case unavailable

    /// The blocker came from an older payload that did not record state basis.
    case legacyPayload = "legacy_payload"
}
