import Foundation

/// External ticket identity linked to a workspace display projection.
public struct ProvenanceWorkspaceDisplayTicketLinkRecord: Codable, Equatable, Sendable, Identifiable {
    /// Ticket identifier, such as `STE-1964` or `BMUX-42`.
    public let id: String

    /// External system that owns the ticket, such as `linear`, `jira`, or `github`.
    public let system: String?

    /// Human-readable ticket title accepted from deterministic evidence, when known.
    public let title: String?

    /// Canonical ticket URL accepted from deterministic evidence, when known.
    public let url: String?

    /// Ticket owner or assignee display name accepted from deterministic evidence, when known.
    public let ownerName: String?

    /// Ticket owner or assignee URL accepted from deterministic evidence, when known.
    public let ownerURL: String?

    /// Creates a workspace-display ticket link fact.
    public init(
        id: String,
        system: String? = nil,
        title: String? = nil,
        url: String? = nil,
        ownerName: String? = nil,
        ownerURL: String? = nil
    ) {
        self.id = id
        self.system = system
        self.title = title
        self.url = url
        self.ownerName = ownerName
        self.ownerURL = ownerURL
    }
}
