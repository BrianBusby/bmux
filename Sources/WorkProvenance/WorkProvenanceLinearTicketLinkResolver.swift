import Foundation
import ProvenanceEngineContracts

/// Resolves Linear ticket titles through Linear's GraphQL API.
actor WorkProvenanceLinearTicketLinkResolver: WorkProvenanceTicketLinkResolving {
    typealias DataProvider = @Sendable (URLRequest) async throws -> (Data, Int)

    private let authorizationProvider: any WorkProvenanceLinearAuthorizationProviding
    private let endpointURL: URL
    private let dataProvider: DataProvider
    private var cache: [String: ProvenanceWorkspaceDisplayTicketLinkRecord] = [:]

    init(
        authorizationHeader: String? = nil,
        usesEnvironmentAuthorization: Bool = true,
        endpointURL: URL = URL(string: "https://api.linear.app/graphql")!,
        authorizationProvider: (any WorkProvenanceLinearAuthorizationProviding)? = nil,
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
        self.dataProvider = dataProvider
    }

    func ticketLinks(for ticketIDs: [String]) async -> [ProvenanceWorkspaceDisplayTicketLinkRecord] {
        var links: [ProvenanceWorkspaceDisplayTicketLinkRecord] = []
        for ticketID in Self.normalizedTicketIDs(ticketIDs) {
            if let cached = cache[ticketID],
               cached.title != nil || cached.ownerName != nil {
                links.append(cached)
                continue
            }

            let issueFacts = await issueFacts(for: ticketID)
            let link = ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: ticketID,
                system: "linear",
                title: issueFacts.title,
                url: Self.linearURL(for: ticketID),
                ownerName: issueFacts.assigneeName
            )
            if issueFacts.title != nil || issueFacts.assigneeName != nil {
                cache[ticketID] = link
            } else {
                cache.removeValue(forKey: ticketID)
            }
            links.append(link)
        }
        return links
    }

    private func issueFacts(for ticketID: String) async -> (title: String?, assigneeName: String?) {
        guard let authorizationHeader = await authorizationProvider.authorizationHeader() else {
            return (title: nil, assigneeName: nil)
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
                assignee {
                  name
                }
              }
            }
            """,
            variables: ["id": ticketID]
        ))
        guard request.httpBody != nil else { return (title: nil, assigneeName: nil) }

        do {
            let (data, statusCode) = try await dataProvider(request)
            guard (200..<300).contains(statusCode) else { return (title: nil, assigneeName: nil) }
            let response = try JSONDecoder().decode(LinearGraphQLResponse.self, from: data)
            guard response.errors?.isEmpty ?? true else { return (title: nil, assigneeName: nil) }
            return (
                title: Self.normalizedNonEmpty(response.data?.issue?.title),
                assigneeName: Self.normalizedNonEmpty(response.data?.issue?.assignee?.name)
            )
        } catch {
            return (title: nil, assigneeName: nil)
        }
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

    private static func linearURL(for ticketID: String) -> String? {
        guard ticketID.range(of: #"^[A-Z][A-Z0-9]+-[0-9]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return "https://linear.app/company/issue/\(ticketID)"
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
        let assignee: LinearAssignee?
    }

    private struct LinearAssignee: Decodable {
        let name: String?
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
