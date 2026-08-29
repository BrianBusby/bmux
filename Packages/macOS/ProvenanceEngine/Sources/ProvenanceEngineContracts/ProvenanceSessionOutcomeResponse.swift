import Foundation

/// Revisioned response for one deterministic coding-agent session outcome.
public struct ProvenanceSessionOutcomeResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether the requested outcome was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Stable Provenance Engine session projection identifier requested by the caller.
    public let sessionID: String

    /// Session outcome, when found.
    public let outcome: ProvenanceSessionOutcome?

    /// Creates a session-outcome response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        sessionID: String,
        outcome: ProvenanceSessionOutcome?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.sessionID = sessionID
        self.outcome = outcome
    }
}
