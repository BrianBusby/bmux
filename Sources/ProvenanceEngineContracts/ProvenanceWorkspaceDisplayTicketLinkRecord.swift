import Foundation

/// External ticket identity linked to a workspace display projection.
public struct ProvenanceWorkspaceDisplayTicketLinkRecord: Codable, Equatable, Sendable, Identifiable {
    /// Ticket identifier, such as `STE-1964` or `BMUX-42`.
    public let id: String

    /// External system that owns the ticket, such as `linear`, `jira`, or `github`.
    public let system: String?

    /// Canonical ticket URL accepted from deterministic evidence, when known.
    public let url: String?

    /// Creates a workspace-display ticket link fact.
    public init(
        id: String,
        system: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.system = system
        self.url = url
    }
}
