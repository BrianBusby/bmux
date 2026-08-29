import Foundation

/// Query parameters for the PE-owned related-session read model.
public struct ProvenanceRelatedSessionRequest: Codable, Equatable, Sendable {
    /// Provenance session identifier used as the relationship target.
    public let targetSessionID: String

    /// Maximum number of related-session briefs to return.
    public let limit: Int

    /// Optional lower bound for candidate freshness.
    public let updatedAfter: Date?

    /// Exact historical related-session projection revision to read.
    public let revisionID: String?

    /// Maximum number of excluded candidates to explain.
    public let exclusionLimit: Int

    /// Creates a related-session query request.
    ///
    /// - Parameters:
    ///   - targetSessionID: Provenance session identifier used as the relationship target.
    ///   - limit: Maximum number of related-session briefs to return.
    ///   - updatedAfter: Optional lower bound for candidate freshness.
    ///   - revisionID: Exact historical projection revision to read.
    ///   - exclusionLimit: Maximum number of excluded candidates to explain.
    public init(
        targetSessionID: String,
        limit: Int = 10,
        updatedAfter: Date? = nil,
        revisionID: String? = nil,
        exclusionLimit: Int = 10
    ) {
        self.targetSessionID = targetSessionID
        self.limit = limit
        self.updatedAfter = updatedAfter
        self.revisionID = revisionID
        self.exclusionLimit = exclusionLimit
    }
}
