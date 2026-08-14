import ProvenanceEngineContracts

/// Resolved external work links for workspace display observation.
struct WorkProvenanceWorkspaceLinkFacts: Equatable, Sendable {
    let ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    let projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]

    init(
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] = [],
        projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord] = []
    ) {
        self.ticketLinks = ticketLinks
        self.projectLinks = projectLinks
    }
}

extension WorkProvenanceWorkspaceLinkFacts {
    var hasEnrichedFacts: Bool {
        ticketLinks.contains { $0.title != nil || $0.ownerName != nil }
            || !projectLinks.isEmpty
    }
}

/// Resolves external ticket and project link metadata for workspace display observation.
protocol WorkProvenanceTicketLinkResolving: Sendable {
    func workspaceLinks(for ticketIDs: [String]) async -> WorkProvenanceWorkspaceLinkFacts
}
