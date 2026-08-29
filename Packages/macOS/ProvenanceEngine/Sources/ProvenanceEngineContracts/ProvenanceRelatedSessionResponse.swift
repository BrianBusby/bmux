import Foundation

/// Revisioned response for a bounded related-session read.
public struct ProvenanceRelatedSessionResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether the target session and requested projection were found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Provenance session identifier requested by the caller.
    public let targetSessionID: String

    /// Related-session projection, when found.
    public let projection: ProvenanceRelatedSessionProjection?

    /// Creates a related-session response.
    ///
    /// - Parameters:
    ///   - schemaVersion: Schema version for this response shape.
    ///   - found: Whether the target session and requested projection were found.
    ///   - reason: Stable reason code when `found` is false.
    ///   - targetSessionID: Provenance session identifier requested by the caller.
    ///   - projection: Related-session projection, when found.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        targetSessionID: String,
        projection: ProvenanceRelatedSessionProjection?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.targetSessionID = targetSessionID
        self.projection = projection
    }
}
