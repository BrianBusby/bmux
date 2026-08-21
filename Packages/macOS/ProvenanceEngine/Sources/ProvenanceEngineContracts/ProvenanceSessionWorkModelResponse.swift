import Foundation

/// Revisioned response for one PE-owned coding-agent session work model.
public struct ProvenanceSessionWorkModelResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether a work model was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Provenance session identifier requested by the caller.
    public let sessionID: String

    /// PE-owned work model, when found.
    public let model: ProvenanceSessionWorkModel?

    /// Creates a SessionWorkModel response.
    ///
    /// - Parameters:
    ///   - schemaVersion: Schema version for this response shape.
    ///   - found: Whether a work model was found.
    ///   - reason: Stable reason code when `found` is false.
    ///   - sessionID: Provenance session identifier requested by the caller.
    ///   - model: PE-owned work model, when found.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        sessionID: String,
        model: ProvenanceSessionWorkModel?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.sessionID = sessionID
        self.model = model
    }
}
