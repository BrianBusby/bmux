import Foundation

/// Revisioned response for one deterministic coding-agent turn outcome.
public struct ProvenanceTurnOutcomeResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether the requested outcome was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Stable Provenance Engine turn projection identifier requested by the caller.
    public let turnID: String

    /// Turn outcome, when found.
    public let outcome: ProvenanceTurnOutcome?

    /// Plan-derived claims in this response are agent-reported and not verified as accepted.
    /// A missing value in an older response must be treated as unknown.
    public let planDerivedClaimsValidity: String?

    /// Creates a turn-outcome response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        turnID: String,
        outcome: ProvenanceTurnOutcome?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.turnID = turnID
        self.outcome = outcome
        self.planDerivedClaimsValidity = outcome == nil ? nil : "unverified_agent_reported"
    }
}
