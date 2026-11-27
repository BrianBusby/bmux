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

    /// Repository-relative path to match against recorded changed artifacts, when supplied.
    public let artifactPath: String?

    /// Case-insensitive objective text fragment, when supplied.
    public let objective: String?

    /// Exact ticket identifier on currently linked workspace metadata, when supplied.
    public let ticket: String?

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
    ///   - artifactPath: Exact repository-relative changed-artifact path, when supplied.
    ///   - objective: Case-insensitive literal objective text fragment, when supplied.
    ///   - ticket: Exact identifier on current workspace ticket metadata, when supplied.
    public init(
        targetSessionID: String,
        limit: Int = 10,
        updatedAfter: Date? = nil,
        revisionID: String? = nil,
        exclusionLimit: Int = 10,
        artifactPath: String? = nil,
        objective: String? = nil,
        ticket: String? = nil
    ) {
        self.targetSessionID = targetSessionID
        self.limit = limit
        self.updatedAfter = updatedAfter
        self.revisionID = revisionID
        self.exclusionLimit = exclusionLimit
        self.artifactPath = artifactPath
        self.objective = objective
        self.ticket = ticket
    }
}
