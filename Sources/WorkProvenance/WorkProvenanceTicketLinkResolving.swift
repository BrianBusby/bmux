import ProvenanceEngineContracts

/// Resolves external ticket link metadata for workspace display observation.
protocol WorkProvenanceTicketLinkResolving: Sendable {
    func ticketLinks(for ticketIDs: [String]) async -> [ProvenanceWorkspaceDisplayTicketLinkRecord]
}
