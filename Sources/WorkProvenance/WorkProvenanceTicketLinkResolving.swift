import ProvenanceEngineContracts

/// Resolved external work links for workspace display observation.
struct WorkProvenanceWorkspaceLinkFacts: Equatable, Sendable {
    struct LookupFailure: Error, Equatable, Sendable {
        enum Reason: String, Sendable {
            case missingAuthorization
            case httpStatus
            case graphQLError
            case missingIssue
            case invalidResponse
            case transport
        }

        let ticketID: String
        let lookupID: String
        let reason: Reason
        let httpStatus: Int?
        let errorDomain: String?
        let errorCode: Int?
        let errorMessage: String?

        init(
            ticketID: String,
            lookupID: String,
            reason: Reason,
            httpStatus: Int? = nil,
            errorDomain: String? = nil,
            errorCode: Int? = nil,
            errorMessage: String? = nil
        ) {
            self.ticketID = ticketID
            self.lookupID = lookupID
            self.reason = reason
            self.httpStatus = httpStatus
            self.errorDomain = errorDomain
            self.errorCode = errorCode
            self.errorMessage = errorMessage
        }
    }

    let ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    let projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    let lookupFailures: [LookupFailure]

    init(
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] = [],
        projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord] = [],
        lookupFailures: [LookupFailure] = []
    ) {
        self.ticketLinks = ticketLinks
        self.projectLinks = projectLinks
        self.lookupFailures = lookupFailures
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
