import Foundation
import Testing
@testable import BmuxWorkBriefSources

@Suite struct URLSessionWorkBriefHTTPClientTests {
    @Test func rejectsOversizedResponseBeforeReturningData() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OversizedWorkBriefURLProtocol.self]
        let client = URLSessionWorkBriefHTTPClient(session: URLSession(configuration: configuration))
        let request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        var rejected = false
        do {
            _ = try await client.response(for: request)
        } catch {
            rejected = true
        }
        #expect(rejected)
    }
}

private final class OversizedWorkBriefURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 65, count: 2_000_001))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
