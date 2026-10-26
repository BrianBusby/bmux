import Foundation
import Testing
@testable import BmuxWorkBriefSources

@Suite struct WorkBriefExternalLoaderTests {
    @Test func localChangesReuseProviderFactsUntilManualRefreshOrIntervalExpires() async {
        let http = CountingHTTP()
        let linear = LinearWorkBriefSource(authorization: { "fixture-token" }, http: http)
        let github = GitHubWorkBriefSource(authorization: { nil }, scopes: { [] }, http: http)
        let loader = WorkBriefExternalLoader(linear: linear, github: github)
        let first = await loader.refresh(at: Date(timeIntervalSince1970: 100), force: false)
        let automatic = await loader.refresh(at: Date(timeIntervalSince1970: 120), force: false)
        #expect(first.0.health.checkedAt == automatic.0.health.checkedAt)
        #expect(await http.count == 1)
        let explicit = await loader.refresh(at: Date(timeIntervalSince1970: 130), force: true)
        #expect(explicit.0.health.checkedAt == Date(timeIntervalSince1970: 130))
        #expect(await http.count == 2)
        _ = await loader.refresh(at: Date(timeIntervalSince1970: 200), force: false)
        #expect(await http.count == 3)
    }
}

private actor CountingHTTP: WorkBriefHTTPClient {
    private(set) var count = 0

    func response(for request: URLRequest) async throws -> (Data, Int) {
        count += 1
        let body = """
        {"data":{"viewer":{"assignedIssues":{"nodes":[],
        "pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
        """
        return (Data(body.utf8), 200)
    }
}
