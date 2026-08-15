import Foundation

/// Revisioned response for one factual session work model snapshot.
public struct ProvenanceSessionWorkModelResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether a session work model snapshot was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Provenance session identifier requested by the caller.
    public let sessionID: String

    /// Factual session work model snapshot, when found.
    public let snapshot: ProvenanceSessionWorkModelSnapshot?

    /// Creates a session work model response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        sessionID: String,
        snapshot: ProvenanceSessionWorkModelSnapshot?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.sessionID = sessionID
        self.snapshot = snapshot
    }
}
