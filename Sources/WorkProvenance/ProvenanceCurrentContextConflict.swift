import Foundation

/// Potential active-contribution overlap returned by a current-context query.
struct ProvenanceCurrentContextConflict: Codable, Equatable, Sendable {
    /// Repository-relative file path with overlapping active contributions.
    let path: String

    /// Number of active contributions touching the path.
    let activeContributionCount: Int

    /// Comma-separated active contribution identifiers in store query order.
    let contributionIDs: String?

    /// Latest file-change update time for the conflicting path.
    let updatedAt: Date

    /// Creates a current-context conflict row.
    init(
        path: String,
        activeContributionCount: Int,
        contributionIDs: String?,
        updatedAt: Date
    ) {
        self.path = path
        self.activeContributionCount = activeContributionCount
        self.contributionIDs = contributionIDs
        self.updatedAt = updatedAt
    }
}
