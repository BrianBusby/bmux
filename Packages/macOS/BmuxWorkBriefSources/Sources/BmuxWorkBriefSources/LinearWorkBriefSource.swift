import BmuxWorkBrief
import Foundation

/// Reads assigned Linear issue summaries and preserves last good facts on failure.
public actor LinearWorkBriefSource {
    /// Resolves established Linear authorization without exposing it in diagnostics.
    public typealias Authorization = @Sendable () async -> String?

    private let authorization: Authorization
    private let http: any WorkBriefHTTPClient
    private let endpoint: URL
    private var lastGood: [WorkBriefExternalItem] = []

    /// Creates a source with injected credentials, transport, and endpoint.
    /// - Parameters:
    ///   - authorization: Supplies the established Linear authorization header.
    ///   - http: The injected bounded response transport.
    ///   - endpoint: The Linear GraphQL endpoint, overridable for tests.
    public init(authorization: @escaping Authorization, http: any WorkBriefHTTPClient,
                endpoint: URL = URL(string: "https://api.linear.app/graphql")!) {
        self.authorization = authorization
        self.http = http
        self.endpoint = endpoint
    }

    /// Refreshes at most 100 issue summaries across two pages; descriptions are never requested.
    /// - Parameter now: Time assigned to this refresh attempt.
    /// - Returns: Bounded issue facts and explicit source health.
    public func refresh(at now: Date) async -> WorkBriefExternalRefresh {
        guard let token = await authorization(), !token.isEmpty else {
            return WorkBriefExternalRefresh(items: lastGood,
                health: WorkBriefSourceHealth(state: .notConfigured, checkedAt: now,
                    reasonCode: "missing_credentials"))
        }
        var items: [WorkBriefExternalItem] = []
        var cursor: String?
        var partial = false
        pages: for _ in 0..<2 {
            let outcome = await page(after: cursor, authorization: token, checkedAt: now)
            switch outcome {
            case .failure(let reason):
                let retained = items.isEmpty ? lastGood : Self.merging(items, with: lastGood)
                return WorkBriefExternalRefresh(items: retained,
                    health: WorkBriefSourceHealth(state: items.isEmpty ? .failed : .partial,
                        checkedAt: now, reasonCode: reason.rawValue))
            case .success(let page):
                items.append(contentsOf: page.items)
                partial = partial || page.partial
                if !page.hasNextPage { cursor = nil; break pages }
                guard let next = page.endCursor, !next.isEmpty else {
                    return WorkBriefExternalRefresh(items: Self.merging(items, with: lastGood),
                        health: WorkBriefSourceHealth(state: .partial, checkedAt: now,
                            reasonCode: "missing_cursor"))
                }
                cursor = next
            }
        }
        if cursor != nil { partial = true }
        let visible = partial ? Self.merging(items, with: lastGood) : Array(items.prefix(100))
        if !partial { lastGood = visible }
        return WorkBriefExternalRefresh(items: visible,
            health: WorkBriefSourceHealth(state: partial ? .partial : .available, checkedAt: now,
                reasonCode: partial ? "page_limit_or_partial_response" : nil))
    }

    private func page(after cursor: String?, authorization: String,
                      checkedAt: Date) async -> Result<Page, PageFailure> {
        let query = """
        query BmuxWorkBriefAssigned($after: String) {
          viewer {
            assignedIssues(first: 50, after: $after, orderBy: updatedAt) {
              nodes { id identifier title url updatedAt state { name type } }
              pageInfo { hasNextPage endCursor }
            }
          }
        }
        """
        let body: [String: Any] = ["query": query, "variables": ["after": cursor as Any? ?? NSNull()]]
        guard let encoded = try? JSONSerialization.data(withJSONObject: body) else { return .failure(.requestEncoding) }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = encoded
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        do {
            let (data, status) = try await http.response(for: request)
            guard (200..<300).contains(status) else {
                return .failure(status == 401 || status == 403 ? .unauthorized : .httpFailure)
            }
            guard data.count <= 2_000_000,
                  let decoded = try? JSONDecoder().decode(LinearWorkBriefResponse.self, from: data),
                  let connection = decoded.data?.viewer?.assignedIssues else { return .failure(.invalidResponse) }
            let items = connection.nodes.prefix(50).compactMap { item($0, checkedAt: checkedAt) }
            return .success(Page(items: items, hasNextPage: connection.pageInfo.hasNextPage,
                endCursor: connection.pageInfo.endCursor, partial: !(decoded.errors?.isEmpty ?? true)))
        } catch {
            return .failure(.transportFailure)
        }
    }

    private func item(_ issue: LinearWorkBriefResponse.Issue,
                      checkedAt: Date) -> WorkBriefExternalItem? {
        guard let url = URL(string: issue.url), url.scheme == "https", url.host != nil,
              !issue.id.isEmpty, !issue.identifier.isEmpty,
              let updatedAt = Self.timestamp(issue.updatedAt) else { return nil }
        let kind = issue.state.type.lowercased()
        guard kind != "completed", kind != "canceled" else { return nil }
        let disposition: WorkBriefExternalItem.Disposition =
            kind == "unstarted" || kind == "triage" ? .needsAttention : .inProgress
        let id = "linear:\(String(issue.id.prefix(120)))"
        return WorkBriefExternalItem(id: id, source: .linear,
            title: String(issue.title.prefix(200)), url: url,
            reference: String(issue.identifier.prefix(80)), repository: nil,
            owner: nil, status: String(issue.state.name.prefix(80)),
            updatedAt: updatedAt, checkedAt: checkedAt, disposition: disposition,
            evidence: [WorkBriefEvidence(id: "\(id):assignment", source: .linear,
                field: "assignedIssue", isObserved: true, checkedAt: checkedAt, url: url)])
    }

    private static func merging(_ current: [WorkBriefExternalItem],
                                with old: [WorkBriefExternalItem]) -> [WorkBriefExternalItem] {
        var seen = Set<String>()
        return Array((current + old).filter { seen.insert($0.id).inserted }.prefix(100))
    }

    private static func timestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private enum PageFailure: String, Error {
        case requestEncoding = "request_encoding"
        case unauthorized
        case httpFailure = "http_failure"
        case invalidResponse = "invalid_response"
        case transportFailure = "transport_failure"
    }

    private struct Page {
        let items: [WorkBriefExternalItem]
        let hasNextPage: Bool
        let endCursor: String?
        let partial: Bool
    }
}
