import Foundation

/// Resolves Linear issue titles through Linear's GraphQL API.
struct WorkProvenanceLinearTicketTitleResolver: WorkProvenanceTicketTitleResolving {
    typealias RequestLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let endpoint: URL
    private let apiKeyProvider: @Sendable () async -> String?
    private let load: RequestLoader

    init(
        endpoint: URL = URL(string: "https://api.linear.app/graphql")!,
        apiKeyProvider: @escaping @Sendable () async -> String?,
        load: @escaping RequestLoader = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.endpoint = endpoint
        self.apiKeyProvider = apiKeyProvider
        self.load = load
    }

    func titles(for ticketIDs: [String]) async -> [String: String] {
        let normalizedTicketIDs = Self.normalizedTicketIDs(ticketIDs)
        guard !normalizedTicketIDs.isEmpty,
              let authorization = Self.normalizedNonEmpty(await apiKeyProvider()) else {
            return [:]
        }

        var titlesByID: [String: String] = [:]
        for ticketID in normalizedTicketIDs {
            if let title = await title(for: ticketID, authorization: authorization) {
                titlesByID[ticketID] = title
            }
        }
        return titlesByID
    }

    private func title(for ticketID: String, authorization: String) async -> String? {
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 4
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(GraphQLRequest(
                query: Self.issueTitleQuery,
                variables: GraphQLRequest.Variables(id: ticketID)
            ))

            let (data, response) = try await load(request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                return nil
            }
            let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)
            guard graphQLResponse.errors?.isEmpty ?? true else { return nil }
            return Self.normalizedNonEmpty(graphQLResponse.data?.issue?.title)
        } catch {
            return nil
        }
    }

    private static let issueTitleQuery = """
    query BmuxWorkspaceTicketTitle($id: String!) {
      issue(id: $id) {
        title
      }
    }
    """

    private static func normalizedTicketIDs(_ ticketIDs: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for ticketID in ticketIDs {
            let uppercased = ticketID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard uppercased.range(
                of: #"^[A-Z][A-Z0-9]+-[0-9]+$"#,
                options: .regularExpression
            ) != nil else {
                continue
            }
            if seen.insert(uppercased).inserted {
                normalized.append(uppercased)
            }
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

    private struct GraphQLRequest: Encodable {
        let query: String
        let variables: Variables

        struct Variables: Encodable {
            let id: String
        }
    }

    private struct GraphQLResponse: Decodable {
        let data: ResponseData?
        let errors: [GraphQLError]?

        struct ResponseData: Decodable {
            let issue: Issue?
        }

        struct Issue: Decodable {
            let title: String?
        }

        struct GraphQLError: Decodable {
            let message: String?
        }
    }
}
