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
    /// - Parameters:
    ///   - authorization: Supplies the established GitHub authorization header.
    ///   - scopes: Supplies explicit organization or repository search scopes.
    ///   - http: The injected bounded response transport.
    ///   - endpoint: The GitHub API endpoint, overridable for tests.
    public init(authorization: @escaping Authorization, scopes: @escaping Scopes,
                http: any WorkBriefHTTPClient,
                endpoint: URL = URL(string: "https://api.github.com")!) {
        self.authorization = authorization
        self.scopes = scopes
        self.http = http
        self.endpoint = endpoint
    }

    /// Refreshes at most four explicit scopes and 100 item summaries.
    /// - Parameter now: Time assigned to this refresh attempt.
    /// - Returns: Bounded pull-request facts and explicit source health.
    public func refresh(at now: Date) async -> WorkBriefExternalRefresh {
        let configured = Array(Set(scopes()).sorted { $0.qualifier < $1.qualifier }.prefix(4))
        guard !configured.isEmpty else { return outcome(.notConfigured, now, "missing_scope") }
        guard let header = await authorization(), !header.isEmpty else {
            return outcome(.notConfigured, now, "missing_credentials")
        }
        let (login, viewerFailure) = await viewerLogin(header: header)
        guard let login else {
            return outcome(.failed, now, viewerFailure)
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
        let authored = facts.values.filter { $0.disposition == .inProgress }
            .sorted { $0.updatedAt > $1.updatedAt }
        if authored.count > 10 { partial = true }
        let reviewResults = await withTaskGroup(of: (WorkBriefExternalItem, Bool?).self) { group in
            for item in authored.prefix(10) {
                group.addTask { (item, await self.hasRequestedReviewers(for: item, header: header)) }
            }
            var results: [(WorkBriefExternalItem, Bool?)] = []
            for await result in group { results.append(result) }
            return results
        }
        for (item, waiting) in reviewResults {
            guard let waiting else { partial = true; continue }
            if waiting {
                facts[item.id] = WorkBriefExternalItem(id: item.id, source: .github,
                    title: item.title, url: item.url, reference: item.reference,
                    repository: item.repository, owner: item.owner,
                    status: "review_requested", updatedAt: item.updatedAt,
                    checkedAt: item.checkedAt, disposition: .waitingOn,
                    evidence: item.evidence + [WorkBriefEvidence(
                        id: "\(item.id):reviewers", source: .github,
                        field: "awaitingReview", isObserved: true, checkedAt: now,
                        url: item.url)])
            }
        }
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

    private func viewerLogin(header: String) async -> (String?, String) {
        guard let url = URL(string: "user", relativeTo: endpoint)?.absoluteURL,
              let response = await get(url: url, header: header) else {
            return (nil, "transport_failure")
        }
        guard response.1 != 401 && response.1 != 403 else { return (nil, "unauthorized") }
        guard response.1 == 200, response.0.count <= 100_000,
              let user = try? JSONDecoder().decode(GitHubWorkBriefViewer.self, from: response.0),
              !user.login.isEmpty, user.login.count <= 50,
              user.login.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
        else { return (nil, "viewer_invalid") }
        return (user.login, "")
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
        return SearchResult(items: items,
            partial: result.incomplete_results || result.total_count > 50 ||
                result.items.prefix(50).count != items.count)
    }

    private func hasRequestedReviewers(for item: WorkBriefExternalItem,
                                       header: String) async -> Bool? {
        guard let repository = item.repository,
              let number = Int(item.reference.dropFirst()), number > 0,
              let url = URL(string: "repos/\(repository)/pulls/\(number)/requested_reviewers",
                            relativeTo: endpoint)?.absoluteURL,
              let response = await get(url: url, header: header), response.1 == 200,
              response.0.count <= 200_000,
              let decoded = try? JSONDecoder().decode(GitHubReviewRequestsResponse.self,
                                                      from: response.0) else { return nil }
        return !decoded.users.isEmpty || !decoded.teams.isEmpty
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
            owner: String(pullRequest.user.login.prefix(80)), status: "open",
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
