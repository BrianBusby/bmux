import Foundation

/// Evidence basis used to assign a stable coding-agent blocker identity.
public enum ProvenanceCodingAgentBlockerIdentityBasis: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Identity is anchored to normalized activity and condition text in a visible agent statement.
    case visibleStatementActivityCondition = "visible_statement_activity_condition"

    /// Identity is anchored to normalized activity and condition text plus a same-session milestone id.
    case visibleStatementActivityConditionMilestone = "visible_statement_activity_condition_milestone"

    /// The blocker came from an older payload that did not record identity basis.
    case legacyPayload = "legacy_payload"
}
