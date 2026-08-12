import Foundation
import ProvenanceEngineContracts

/// Resolves Linear ticket titles through Linear's GraphQL API.
actor WorkProvenanceLinearTicketLinkResolver: WorkProvenanceTicketLinkResolving {
    typealias DataProvider = @Sendable (URLRequest) async throws -> (Data, Int)

    private let authorizationHeader: String?
    private let endpointURL: URL
    private let dataProvider: DataProvider
    private var cache: [String: ProvenanceWorkspaceDisplayTicketLinkRecord] = [:]

    init(
        authorizationHeader: String? = nil,
        usesEnvironmentAuthorization: Bool = true,
        endpointURL: URL = URL(string: "https://api.linear.app/graphql")!,
        dataProvider: @escaping DataProvider = { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, statusCode)
        }
    ) {
        self.authorizationHeader = Self.normalizedNonEmpty(authorizationHeader)
            ?? (usesEnvironmentAuthorization ? Self.defaultAuthorizationHeader() : nil)
        self.endpointURL = endpointURL
        self.dataProvider = dataProvider
    }

    func ticketLinks(for ticketIDs: [String]) async -> [ProvenanceWorkspaceDisplayTicketLinkRecord] {
        var links: [ProvenanceWorkspaceDisplayTicketLinkRecord] = []
        for ticketID in Self.normalizedTicketIDs(ticketIDs) {
            if let cached = cache[ticketID] {
                links.append(cached)
                continue
            }

            let title = await title(for: ticketID)
            let link = ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: ticketID,
                system: "linear",
                title: title,
                url: Self.linearURL(for: ticketID)
            )
            cache[ticketID] = link
            links.append(link)
        }
        return links
    }

    private func title(for ticketID: String) async -> String? {
        guard let authorizationHeader else { return nil }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(LinearGraphQLRequest(
            query: """
            query BmuxLinearIssueTitle($id: String!) {
              issue(id: $id) {
                title
              }
            }
            """,
            variables: ["id": ticketID]
        ))
        guard request.httpBody != nil else { return nil }

        do {
            let (data, statusCode) = try await dataProvider(request)
            guard (200..<300).contains(statusCode) else { return nil }
            let response = try JSONDecoder().decode(LinearGraphQLResponse.self, from: data)
            guard response.errors?.isEmpty ?? true else { return nil }
            return Self.normalizedNonEmpty(response.data?.issue?.title)
        } catch {
            return nil
        }
    }

    private static func defaultAuthorizationHeader(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        for key in ["BMUX_LINEAR_AUTHORIZATION", "LINEAR_AUTHORIZATION"] {
            if let value = normalizedNonEmpty(environment[key]) {
                return value
            }
        }
        for key in ["BMUX_LINEAR_API_KEY", "LINEAR_API_KEY", "LINEAR_API_TOKEN"] {
            if let value = normalizedNonEmpty(environment[key]) {
                return value
            }
        }
        for key in ["BMUX_LINEAR_ACCESS_TOKEN", "LINEAR_ACCESS_TOKEN"] {
            if let value = normalizedNonEmpty(environment[key]) {
                return "Bearer \(value)"
            }
        }
        return nil
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
    }

    private struct LinearGraphQLError: Decodable {
        let message: String?
    }
}
