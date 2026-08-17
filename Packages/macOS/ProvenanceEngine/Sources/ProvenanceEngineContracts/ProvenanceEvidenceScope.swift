import Foundation

/// Coarse ownership boundary for an evidence event.
public struct ProvenanceEvidenceScope: Codable, Equatable, Hashable, Sendable {
    /// Scope boundary.
    public let level: ProvenanceEvidenceScopeLevel

    /// Stable scope identifier, such as a user, project, or organization slug.
    public let id: String?

    /// Creates an evidence scope.
    ///
    /// - Parameters:
    ///   - level: Coarse evidence boundary.
    ///   - id: Stable boundary identifier when known.
    public init(level: ProvenanceEvidenceScopeLevel, id: String? = nil) {
        self.level = level
        self.id = id
    }
}

/// Coarse evidence ownership boundary.
public enum ProvenanceEvidenceScopeLevel: String, Codable, CaseIterable, Sendable {
    /// Private evidence for one engineer or local installation.
    case personal

    /// Shared evidence for one project or repository family.
    case project

    /// Shared evidence for an organization.
    case organization
}
