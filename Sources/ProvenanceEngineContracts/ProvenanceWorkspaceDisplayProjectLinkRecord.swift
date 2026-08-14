import Foundation

/// External project identity linked to a workspace display projection.
public struct ProvenanceWorkspaceDisplayProjectLinkRecord: Codable, Equatable, Sendable, Identifiable {
    /// Project identifier, such as a Linear project slug.
    public let id: String

    /// External system that owns the project, such as `linear`.
    public let system: String?

    /// Human-readable project title accepted from deterministic evidence, when known.
    public let title: String?

    /// Canonical project URL accepted from deterministic evidence, when known.
    public let url: String?

    /// Creates a workspace-display project link fact.
    public init(
        id: String,
        system: String? = nil,
        title: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.system = system
        self.title = title
        self.url = url
    }
}
