import Foundation
import Testing
@testable import BmuxWorkBriefSources

@Suite struct GitHubWorkBriefSourceTests {
    @Test func acceptsOnlyExplicitNarrowScopes() {
        #expect(GitHubWorkBriefScope("org:CompanyCam") != nil)
        #expect(GitHubWorkBriefScope("repo:CompanyCam/mobile") != nil)
        #expect(GitHubWorkBriefScope("org:CompanyCam author:other") == nil)
        #expect(GitHubWorkBriefScope("repo:CompanyCam") == nil)
        #expect(GitHubWorkBriefScope("org:*") == nil)
    }

    @Test func reviewRequestsAndAuthoredPRsAreScopedAndDeduplicated() async {
        let http = GitHubStubHTTP(viewer: viewer(), review: search([
            pull(id: 11, number: 12, title: "Check roof photos"),
        ]), authored: search([
            pull(id: 11, number: 12, title: "Check roof photos"),
            pull(id: 13, number: 14, title: "Upload field notes"),
        ]))
        let source = GitHubWorkBriefSource(authorization: { "Bearer fixture-token" },
            scopes: { [GitHubWorkBriefScope("org:CompanyCam")!] }, http: http)
        let result = await source.refresh(at: Date(timeIntervalSince1970: 100))
        #expect(result.health.state == .available)
        #expect(result.items.count == 2)
        #expect(result.items.first { $0.id == "github:11" }?.disposition == .needsAttention)
        #expect(result.items.first { $0.id == "github:13" }?.disposition == .inProgress)
        let queries = await http.queries
        #expect(queries.count == 2)
        #expect(queries.allSatisfy { $0.contains("org:CompanyCam") })
        #expect(queries.contains { $0.contains("review-requested:brian") })
        #expect(queries.contains { $0.contains("author:brian") })
    }

    @Test func noScopeDoesNotContactGitHub() async {
        let source = GitHubWorkBriefSource(authorization: { "Bearer fixture-token" },
            scopes: { [] }, http: GitHubStubHTTP(viewer: viewer(), review: search([]), authored: search([])))
        let result = await source.refresh(at: Date())
        #expect(result.health.state == .notConfigured)
        #expect(result.health.reasonCode == "missing_scope")
    }

    private func viewer() -> Data {
        Data("{\"login\":\"brian\"}".utf8)
    }

    private func pull(id: Int, number: Int, title: String) -> [String: Any] {
        ["id": id, "number": number, "title": title,
         "html_url": "https://github.com/CompanyCam/mobile/pull/\(number)",
         "repository_url": "https://api.github.com/repos/CompanyCam/mobile",
         "updated_at": "2026-10-26T11:00:00Z", "user": ["login": "brian"]]
    }

    private func search(_ items: [[String: Any]]) -> Data {
        (try? JSONSerialization.data(withJSONObject: [
            "total_count": items.count, "incomplete_results": false, "items": items
        ])) ?? Data()
    }
}

private actor GitHubStubHTTP: WorkBriefHTTPClient {
    let viewer: Data
    let review: Data
    let authored: Data
    private(set) var queries: [String] = []

    init(viewer: Data, review: Data, authored: Data) {
        self.viewer = viewer
        self.review = review
        self.authored = authored
    }

    func response(for request: URLRequest) async throws -> (Data, Int) {
        guard let url = request.url else { throw URLError(.badURL) }
        if url.path == "/user" { return (viewer, 200) }
        guard url.path == "/search/issues",
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "q" })?.value else {
            throw URLError(.badURL)
        }
        queries.append(query)
        return (query.contains("review-requested:") ? review : authored, 200)
    }
}
