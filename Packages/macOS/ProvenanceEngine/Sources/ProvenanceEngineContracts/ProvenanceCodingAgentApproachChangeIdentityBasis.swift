import Foundation

/// Evidence basis used to assign a stable coding-agent approach-change identity.
public enum ProvenanceCodingAgentApproachChangeIdentityBasis: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Identity is anchored to a normalized visible statement describing the strategy transition.
    case visibleStatementStrategyTransition = "visible_statement_strategy_transition"

    /// Identity is anchored to the strategy transition plus a same-session milestone id.
    case visibleStatementStrategyTransitionMilestone = "visible_statement_strategy_transition_milestone"

    /// The approach change came from an older payload that did not record identity basis.
    case legacyPayload = "legacy_payload"
}
