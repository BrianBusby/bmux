import Foundation

/// Revisioned response for one factual session projection snapshot.
public struct ProvenanceFactualSessionProjectionResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether a factual session projection snapshot was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Provenance session identifier requested by the caller.
    public let sessionID: String

    /// Factual session projection snapshot, when found.
    public let snapshot: ProvenanceFactualSessionProjectionSnapshot?

    /// Creates a factual session projection response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        sessionID: String,
        snapshot: ProvenanceFactualSessionProjectionSnapshot?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.sessionID = sessionID
        self.snapshot = snapshot
    }
}
