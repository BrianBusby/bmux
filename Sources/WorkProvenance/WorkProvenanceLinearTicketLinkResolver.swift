import Foundation
import ProvenanceEngineContracts

/// Resolves Linear ticket titles through Linear's GraphQL API.
actor WorkProvenanceLinearTicketLinkResolver: WorkProvenanceTicketLinkResolving {
    typealias DataProvider = @Sendable (URLRequest) async throws -> (Data, Int)

    private let authorizationProvider: any WorkProvenanceLinearAuthorizationProviding
    private let endpointURL: URL
    private let dataProvider: DataProvider
    private let webLinkBuilder: LinearWebLinkBuilder
    private let ticketIdentifierAliasMap: LinearTicketIdentifierAliasMap
    private var cache: [String: WorkProvenanceWorkspaceLinkFacts] = [:]
    private var lastFailuresByTicketID: [String: [WorkProvenanceWorkspaceLinkFacts.LookupFailure]] = [:]

    init(
        authorizationHeader: String? = nil,
        usesEnvironmentAuthorization: Bool = true,
        endpointURL: URL = URL(string: "https://api.linear.app/graphql")!,
        authorizationProvider: (any WorkProvenanceLinearAuthorizationProviding)? = nil,
        webLinkBuilder: LinearWebLinkBuilder = LinearWebLinkBuilder(),
        ticketIdentifierAliasMap: LinearTicketIdentifierAliasMap = .companyCam,
        dataProvider: @escaping DataProvider = { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, statusCode)
        }
    ) {
        if let authorizationHeader = Self.normalizedNonEmpty(authorizationHeader) {
            self.authorizationProvider = StaticLinearAuthorizationProvider(authorizationHeader)
        } else if let authorizationProvider {
            self.authorizationProvider = authorizationProvider
        } else if usesEnvironmentAuthorization {
            self.authorizationProvider = WorkProvenanceEnvironmentLinearAuthorizationProvider()
        } else {
            self.authorizationProvider = StaticLinearAuthorizationProvider(nil)
        }
        self.endpointURL = endpointURL
        self.webLinkBuilder = webLinkBuilder
        self.ticketIdentifierAliasMap = ticketIdentifierAliasMap
        self.dataProvider = dataProvider
    }

    func workspaceLinks(for ticketIDs: [String]) async -> WorkProvenanceWorkspaceLinkFacts {
        var ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] = []
        var projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord] = []
        var lookupFailures: [WorkProvenanceWorkspaceLinkFacts.LookupFailure] = []
        var seenProjectIDs = Set<String>()
        for ticketID in Self.normalizedTicketIDs(ticketIDs) {
            if let cached = cache[ticketID],
               cached.hasEnrichedFacts {
                ticketLinks.append(contentsOf: cached.ticketLinks)
                for projectLink in cached.projectLinks where seenProjectIDs.insert(projectLink.id).inserted {
                    projectLinks.append(projectLink)
                }
                continue
            }

            let resolution = await issueFacts(for: ticketID)
            let issueFacts = resolution.facts
            if resolution.failures.isEmpty {
                if lastFailuresByTicketID.removeValue(forKey: ticketID) != nil {
                    StartupBreadcrumbLog.append("linear.lookup.recovered", fields: ["ticketID": ticketID])
                    NSLog("bmux linear lookup recovered ticket=%@", ticketID)
                }
            } else {
                lastFailuresByTicketID[ticketID] = resolution.failures
                lookupFailures.append(contentsOf: resolution.failures)
                for failure in resolution.failures {
                    let fields = [
                        "ticketID": failure.ticketID,
                        "lookupID": failure.lookupID,
                        "reason": failure.reason.rawValue,
                        "httpStatus": failure.httpStatus.map { String($0) } ?? "",
                        "errorDomain": failure.errorDomain ?? "",
                        "errorCode": failure.errorCode.map { String($0) } ?? "",
                        "errorMessage": failure.errorMessage ?? ""
                    ]
                    StartupBreadcrumbLog.append("linear.lookup.failed", fields: fields)
                    NSLog(
                        "bmux linear lookup failed ticket=%@ lookup=%@ reason=%@ http=%@ domain=%@ code=%@ message=%@",
                        failure.ticketID, failure.lookupID, failure.reason.rawValue,
                        fields["httpStatus"] ?? "", fields["errorDomain"] ?? "",
                        fields["errorCode"] ?? "", fields["errorMessage"] ?? ""
                    )
                }
            }
            let ticketLink = ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: ticketID,
                system: "linear",
                title: issueFacts.title,
                url: webLinkBuilder.issueURLString(apiURL: issueFacts.url, ticketID: ticketID),
                ownerName: issueFacts.assigneeName
            )
            let resolvedProjectLinks = issueFacts.projectLink.map { [$0] } ?? []
            let facts = WorkProvenanceWorkspaceLinkFacts(
                ticketLinks: [ticketLink],
                projectLinks: resolvedProjectLinks
            )
            if facts.hasEnrichedFacts {
                cache[ticketID] = facts
            } else {
                cache.removeValue(forKey: ticketID)
            }
            ticketLinks.append(ticketLink)
            for projectLink in resolvedProjectLinks where seenProjectIDs.insert(projectLink.id).inserted {
                projectLinks.append(projectLink)
            }
        }
        return WorkProvenanceWorkspaceLinkFacts(
            ticketLinks: ticketLinks, projectLinks: projectLinks, lookupFailures: lookupFailures
        )
    }

    func lastLookupFailures(for ticketID: String) -> [WorkProvenanceWorkspaceLinkFacts.LookupFailure] {
        lastFailuresByTicketID[ticketID.uppercased()] ?? []
    }

    private func issueFacts(for ticketID: String) async -> (
        facts: LinearIssueFacts, failures: [WorkProvenanceWorkspaceLinkFacts.LookupFailure]
    ) {
        guard let authorizationHeader = await authorizationProvider.authorizationHeader() else {
            return (.empty, [.init(ticketID: ticketID, lookupID: ticketID, reason: .missingAuthorization)])
        }
        var failures: [WorkProvenanceWorkspaceLinkFacts.LookupFailure] = []
        for lookupTicketID in ticketIdentifierAliasMap.lookupCandidates(for: ticketID) {
            switch await issueFacts(
                forLookupTicketID: lookupTicketID,
                observedTicketID: ticketID,
                authorizationHeader: authorizationHeader
            ) {
            case .success(let facts):
                return (facts, [])
            case .failure(let failure):
                failures.append(failure)
            }
        }
        return (.empty, failures)
    }

    private func issueFacts(
        forLookupTicketID ticketID: String,
        observedTicketID: String,
        authorizationHeader: String
    ) async -> Result<LinearIssueFacts, WorkProvenanceWorkspaceLinkFacts.LookupFailure> {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(LinearGraphQLRequest(
            query: """
            query BmuxLinearIssueDetails($id: String!) {
              issue(id: $id) {
                title
                url
                assignee {
                  name
                }
                project {
                  id
                  name
                  url
                  slugId
                }
              }
            }
            """,
            variables: ["id": ticketID]
        ))
        guard request.httpBody != nil else {
            return .failure(.init(ticketID: observedTicketID, lookupID: ticketID, reason: .invalidResponse))
        }

        do {
            let (data, statusCode) = try await dataProvider(request)
            guard (200..<300).contains(statusCode) else {
                return .failure(.init(
                    ticketID: observedTicketID, lookupID: ticketID,
                    reason: .httpStatus, httpStatus: statusCode
                ))
            }
            let response: LinearGraphQLResponse
            do {
                response = try JSONDecoder().decode(LinearGraphQLResponse.self, from: data)
            } catch {
                return .failure(.init(ticketID: observedTicketID, lookupID: ticketID, reason: .invalidResponse))
            }
            guard response.errors?.isEmpty ?? true else {
                return .failure(.init(
                    ticketID: observedTicketID, lookupID: ticketID, reason: .graphQLError,
                    errorMessage: response.errors?.compactMap(\.message).first.map { String($0.prefix(240)) }
                ))
            }
            guard let issue = response.data?.issue else {
                return .failure(.init(ticketID: observedTicketID, lookupID: ticketID, reason: .missingIssue))
            }
            return .success(LinearIssueFacts(
                title: Self.normalizedNonEmpty(issue.title),
                url: Self.normalizedNonEmpty(issue.url),
                assigneeName: Self.normalizedNonEmpty(issue.assignee?.name),
                projectLink: projectLink(from: issue.project)
            ))
        } catch {
            let nsError = error as NSError
            return .failure(.init(
                ticketID: observedTicketID, lookupID: ticketID,
                reason: .transport, errorDomain: nsError.domain, errorCode: nsError.code
            ))
        }
    }

    private func projectLink(from project: LinearProject?) -> ProvenanceWorkspaceDisplayProjectLinkRecord? {
        guard let project else { return nil }
        let slugID = Self.normalizedNonEmpty(project.slugId)
        let id = slugID ?? Self.normalizedNonEmpty(project.id)
        guard let id else { return nil }
        return ProvenanceWorkspaceDisplayProjectLinkRecord(
            id: id,
            system: "linear",
            title: Self.normalizedNonEmpty(project.name),
            url: webLinkBuilder.projectURLString(apiURL: project.url, projectSlug: slugID)
        )
    }

    private static func normalizedTicketIDs(_ ticketIDs: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for ticketID in ticketIDs {
            guard let value = normalizedNonEmpty(ticketID)?.uppercased(),
                  seen.insert(value).inserted else {
                continue
            }
            normalized.append(value)
        }
        return normalized
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private struct LinearGraphQLRequest: Encodable {
        let query: String
        let variables: [String: String]
    }

    private struct LinearGraphQLResponse: Decodable {
        let data: LinearGraphQLData?
        let errors: [LinearGraphQLError]?
    }

    private struct LinearGraphQLData: Decodable {
        let issue: LinearIssue?
    }

    private struct LinearIssueFacts: Sendable {
        static let empty = LinearIssueFacts(
            title: nil,
            url: nil,
            assigneeName: nil,
            projectLink: nil
        )

        let title: String?
        let url: String?
        let assigneeName: String?
        let projectLink: ProvenanceWorkspaceDisplayProjectLinkRecord?
    }

    private struct LinearIssue: Decodable {
        let title: String?
        let url: String?
        let assignee: LinearAssignee?
        let project: LinearProject?
    }

    private struct LinearAssignee: Decodable {
        let name: String?
    }

    private struct LinearProject: Decodable {
        let id: String?
        let name: String?
        let url: String?
        let slugId: String?
    }

    private struct LinearGraphQLError: Decodable {
        let message: String?
    }

    private struct StaticLinearAuthorizationProvider: WorkProvenanceLinearAuthorizationProviding {
        let header: String?

        init(_ header: String?) {
            self.header = header
        }

        func authorizationHeader() async -> String? {
            header
        }
    }
}
