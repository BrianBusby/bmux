import Foundation
import ProvenanceEngineContracts

/// Resolves Linear ticket titles through Linear's GraphQL API.
actor WorkProvenanceLinearTicketLinkResolver: WorkProvenanceTicketLinkResolving {
    typealias DataProvider = @Sendable (URLRequest) async throws -> (Data, Int)

    private let authorizationProvider: any WorkProvenanceLinearAuthorizationProviding
    private let endpointURL: URL
    private let dataProvider: DataProvider
    private let webLinkBuilder: LinearWebLinkBuilder
    private var cache: [String: WorkProvenanceWorkspaceLinkFacts] = [:]

    init(
        authorizationHeader: String? = nil,
        usesEnvironmentAuthorization: Bool = true,
        endpointURL: URL = URL(string: "https://api.linear.app/graphql")!,
        authorizationProvider: (any WorkProvenanceLinearAuthorizationProviding)? = nil,
        webLinkBuilder: LinearWebLinkBuilder = LinearWebLinkBuilder(),
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
        self.dataProvider = dataProvider
    }

    func workspaceLinks(for ticketIDs: [String]) async -> WorkProvenanceWorkspaceLinkFacts {
        var ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] = []
        var projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord] = []
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

            let issueFacts = await issueFacts(for: ticketID)
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
        return WorkProvenanceWorkspaceLinkFacts(ticketLinks: ticketLinks, projectLinks: projectLinks)
    }

    private func issueFacts(
        for ticketID: String
    ) async -> (
        title: String?,
        url: String?,
        assigneeName: String?,
        projectLink: ProvenanceWorkspaceDisplayProjectLinkRecord?
    ) {
        guard let authorizationHeader = await authorizationProvider.authorizationHeader() else {
            return (title: nil, url: nil, assigneeName: nil, projectLink: nil)
        }
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
        guard request.httpBody != nil else { return (title: nil, url: nil, assigneeName: nil, projectLink: nil) }

        do {
            let (data, statusCode) = try await dataProvider(request)
            guard (200..<300).contains(statusCode) else { return (title: nil, url: nil, assigneeName: nil, projectLink: nil) }
            let response = try JSONDecoder().decode(LinearGraphQLResponse.self, from: data)
            guard response.errors?.isEmpty ?? true else { return (title: nil, url: nil, assigneeName: nil, projectLink: nil) }
            return (
                title: Self.normalizedNonEmpty(response.data?.issue?.title),
                url: Self.normalizedNonEmpty(response.data?.issue?.url),
                assigneeName: Self.normalizedNonEmpty(response.data?.issue?.assignee?.name),
                projectLink: projectLink(from: response.data?.issue?.project)
            )
        } catch {
            return (title: nil, url: nil, assigneeName: nil, projectLink: nil)
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
