import Foundation
import Testing
@testable import BmuxWorkBriefSources

@Suite struct LinearWorkBriefSourceTests {
    @Test func missingCredentialsReportUnconfiguredWithoutNetwork() async {
        let source = LinearWorkBriefSource(authorization: { nil }, http: StubHTTP([]))
        let result = await source.refresh(at: Date(timeIntervalSince1970: 100))
        #expect(result.items.isEmpty)
        #expect(result.health.state == .notConfigured)
    }

    @Test func pagesBoundResultsAndSkipUnsafeLinks() async throws {
        let http = StubHTTP([
            .success(page(nodes: [issue("A", url: "https://linear.app/acme/issue/A"),
                                   issue("B", url: "http://example.com/private")],
                          next: "cursor-1")),
            .success(page(nodes: [issue("C", url: "https://linear.app/acme/issue/C")], next: nil))
        ])
        let source = LinearWorkBriefSource(authorization: { "fixture-token" }, http: http)
        let result = await source.refresh(at: Date(timeIntervalSince1970: 100))
        #expect(result.health.state == .available)
        #expect(result.items.map(\.reference) == ["A", "C"])
        #expect(result.items.first?.disposition == .needsAttention)
        #expect(await http.requestCount == 2)
        let cursors = await http.cursors
        #expect(cursors == [nil, "cursor-1"])
    }

    @Test func offlineRefreshKeepsLastGoodFactsAndReportsFailure() async {
        let http = StubHTTP([.success(page(nodes: [issue("A", url: "https://linear.app/acme/issue/A")], next: nil)),
                             .failure(URLError(.notConnectedToInternet))])
        let source = LinearWorkBriefSource(authorization: { "fixture-token" }, http: http)
        let first = await source.refresh(at: Date(timeIntervalSince1970: 100))
        let second = await source.refresh(at: Date(timeIntervalSince1970: 200))
        #expect(first.health.state == .available)
        #expect(second.health.state == .failed)
        #expect(second.health.reasonCode == "transport_failure")
        #expect(second.items == first.items)
        #expect(second.items.first?.checkedAt == Date(timeIntervalSince1970: 100))
    }

    @Test func graphqlErrorsAreVisibleAlongsidePartialFacts() async {
        let body = page(nodes: [issue("A", url: "https://linear.app/acme/issue/A")],
                        next: nil, errors: true)
        let source = LinearWorkBriefSource(authorization: { "fixture-token" },
                                           http: StubHTTP([.success(body)]))
        let result = await source.refresh(at: Date(timeIntervalSince1970: 100))
        #expect(result.items.count == 1)
        #expect(result.health.state == .partial)
    }

    @Test func partialRefreshKeepsFactsMissingFromIncompleteResponse() async {
        let http = StubHTTP([
            .success(page(nodes: [issue("A", url: "https://linear.app/acme/issue/A")], next: nil)),
            .success(page(nodes: [issue("B", url: "https://linear.app/acme/issue/B")],
                          next: nil, errors: true))
        ])
        let source = LinearWorkBriefSource(authorization: { "fixture-token" }, http: http)
        _ = await source.refresh(at: Date(timeIntervalSince1970: 100))
        let partial = await source.refresh(at: Date(timeIntervalSince1970: 200))
        #expect(partial.health.state == .partial)
        #expect(partial.items.map(\.reference) == ["B", "A"])
        #expect(partial.items[1].checkedAt == Date(timeIntervalSince1970: 100))
    }

    private func issue(_ id: String, url: String) -> [String: Any] {
        ["id": id, "identifier": id, "title": "Roof inspection", "url": url,
         "updatedAt": "2026-10-26T11:00:00.000Z",
         "state": ["name": "Todo", "type": "unstarted"]]
    }

    private func page(nodes: [[String: Any]], next: String?, errors: Bool = false) -> Data {
        var payload: [String: Any] = ["data": ["viewer": ["assignedIssues": [
            "nodes": nodes, "pageInfo": ["hasNextPage": next != nil,
                                      "endCursor": next as Any? ?? NSNull()]
        ]]]]
        if errors { payload["errors"] = [["message": "partial fixture"]] }
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

}

private actor StubHTTP: WorkBriefHTTPClient {
    enum Outcome {
        case success(Data)
        case failure(any Error)
    }

    private var outcomes: [Outcome]
    private(set) var requestCount = 0
    private(set) var cursors: [String?] = []

    init(_ outcomes: [Outcome]) { self.outcomes = outcomes }

    func response(for request: URLRequest) async throws -> (Data, Int) {
        requestCount += 1
        if let data = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let variables = json["variables"] as? [String: Any] {
            cursors.append(variables["after"] as? String)
        }
        guard !outcomes.isEmpty else { throw URLError(.badServerResponse) }
        switch outcomes.removeFirst() {
        case .success(let data): return (data, 200)
        case .failure(let error): throw error
        }
    }
}
