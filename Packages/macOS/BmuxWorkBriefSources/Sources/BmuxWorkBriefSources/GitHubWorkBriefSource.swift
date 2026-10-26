import BmuxWorkBrief
import Foundation

/// Searches explicitly scoped GitHub pull requests without storing bodies or comments.
public actor GitHubWorkBriefSource {
    /// Supplies the established GitHub authorization header.
    public typealias Authorization = @Sendable () async -> String?
    /// Supplies explicit organization or repository scopes.
    public typealias Scopes = @Sendable () -> [GitHubWorkBriefScope]

    private let authorization: Authorization
    private let scopes: Scopes
    private let http: any WorkBriefHTTPClient
    private let endpoint: URL
    private var lastGood: [WorkBriefExternalItem] = []

    /// Creates a read-only source with injected credentials, scope, transport, and endpoint.
    public init(authorization: @escaping Authorization, scopes: @escaping Scopes,
                http: any WorkBriefHTTPClient,
                endpoint: URL = URL(string: "https://api.github.com")!) {
        self.authorization = authorization
        self.scopes = scopes
        self.http = http
        self.endpoint = endpoint
    }

    /// Refreshes at most four explicit scopes and 100 item summaries.
    public func refresh(at now: Date) async -> WorkBriefExternalRefresh {
        let configured = Array(Set(scopes()).sorted { $0.qualifier < $1.qualifier }.prefix(4))
        guard !configured.isEmpty else { return outcome(.notConfigured, now, "missing_scope") }
        guard let header = await authorization(), !header.isEmpty else {
            return outcome(.notConfigured, now, "missing_credentials")
        }
        guard let login = await viewerLogin(header: header) else {
            return outcome(.failed, now, "viewer_unavailable")
        }
        var facts: [String: WorkBriefExternalItem] = [:]
        var partial = false
        for scope in configured {
            for category in [Category.reviewRequested, .authored] {
                guard let result = await search(scope: scope, category: category,
                                                login: login, header: header, now: now) else {
                    partial = true
                    continue
                }
                partial = partial || result.partial
                for item in result.items {
                    // A review request takes precedence over the same authored PR.
                    if let previous = facts[item.id], previous.disposition == .needsAttention { continue }
                    facts[item.id] = item
                }
            }
        }
        guard !facts.isEmpty || !partial else { return outcome(.failed, now, "search_failure") }
        if partial {
            for old in lastGood where facts[old.id] == nil { facts[old.id] = old }
        }
        let items = Array(facts.values.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }.prefix(100))
        if !partial { lastGood = items }
        return WorkBriefExternalRefresh(items: partial && items.isEmpty ? lastGood : items,
            health: WorkBriefSourceHealth(state: partial ? .partial : .available,
                checkedAt: now, reasonCode: partial ? "search_partial" : nil))
    }

    private func outcome(_ state: WorkBriefSourceHealth.State, _ now: Date,
                         _ reason: String) -> WorkBriefExternalRefresh {
        WorkBriefExternalRefresh(items: lastGood,
            health: WorkBriefSourceHealth(state: state, checkedAt: now, reasonCode: reason))
    }

    private func viewerLogin(header: String) async -> String? {
        guard let url = URL(string: "user", relativeTo: endpoint)?.absoluteURL,
              let response = await get(url: url, header: header), response.1 == 200,
              response.0.count <= 100_000,
              let user = try? JSONDecoder().decode(GitHubWorkBriefViewer.self, from: response.0),
              !user.login.isEmpty, user.login.count <= 50,
              user.login.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
        else { return nil }
        return user.login
    }

    private func search(scope: GitHubWorkBriefScope, category: Category,
                        login: String, header: String, now: Date) async -> SearchResult? {
        var components = URLComponents(url: endpoint.appendingPathComponent("search/issues"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: "is:pr is:open \(scope.qualifier) \(category.qualifier):\(login)"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "50")
        ]
        guard let url = components?.url,
              let response = await get(url: url, header: header), response.1 == 200,
              response.0.count <= 2_000_000,
              let result = try? JSONDecoder().decode(GitHubWorkBriefSearchResponse.self, from: response.0)
        else { return nil }
        let items = result.items.prefix(50).compactMap { item($0, category: category, checkedAt: now) }
        return SearchResult(items: items, partial: result.incomplete_results || result.total_count > 50)
    }

    private func get(url: URL, header: String) async -> (Data, Int)? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("bmux-work-brief", forHTTPHeaderField: "User-Agent")
        request.setValue(header, forHTTPHeaderField: "Authorization")
        return try? await http.response(for: request)
    }

    private func item(_ pullRequest: GitHubWorkBriefSearchResponse.Item,
                      category: Category, checkedAt: Date) -> WorkBriefExternalItem? {
        guard let url = URL(string: pullRequest.html_url), url.scheme == "https",
              url.host == "github.com", pullRequest.number > 0,
              let repositoryURL = URL(string: pullRequest.repository_url),
              repositoryURL.host == "api.github.com",
              repositoryURL.pathComponents.count >= 4,
              let updatedAt = Self.timestamp(pullRequest.updated_at) else { return nil }
        let repository = repositoryURL.pathComponents.suffix(2).joined(separator: "/")
        let id = "github:\(pullRequest.id)"
        return WorkBriefExternalItem(id: id, source: .github,
            title: String(pullRequest.title.prefix(200)), url: url,
            reference: "#\(pullRequest.number)", repository: repository,
            owner: String(pullRequest.user.login.prefix(80)), status: "Open",
            updatedAt: updatedAt, checkedAt: checkedAt,
            disposition: category == .reviewRequested ? .needsAttention : .inProgress,
            evidence: [WorkBriefEvidence(id: "\(id):\(category.rawValue)", source: .github,
                field: category.rawValue, isObserved: true, checkedAt: checkedAt, url: url)])
    }

    private static func timestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private enum Category: String {
        case reviewRequested = "reviewRequested"
        case authored

        var qualifier: String {
            switch self {
            case .reviewRequested: "review-requested"
            case .authored: "author"
            }
        }
    }

    private struct SearchResult {
        let items: [WorkBriefExternalItem]
        let partial: Bool
    }
}
