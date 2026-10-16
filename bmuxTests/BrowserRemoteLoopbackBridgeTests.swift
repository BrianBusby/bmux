import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct BrowserRemoteLoopbackBridgeTests {
    @Test
    func remoteWorkspaceRuntimeBridgeAliasesMultipleLoopbackPortsFromSamePage() async throws {
        let fixture = BrowserRemoteLoopbackBridgeFixture()
        defer { fixture.close() }
        let baseURL = try #require(URL(string: "http://bmux-loopback.localtest.me:3000/"))

        try await fixture.load(
            "<!doctype html><html><body>remote loopback bridge</body></html>",
            baseURL: baseURL
        )

        let result = try await fixture.panel.evaluateJavaScript(
            """
            (() => {
              const rewrite = window.__bmuxRewriteRemoteLoopbackURL;
              if (typeof rewrite !== 'function') {
                return 'missing bridge';
              }
              return JSON.stringify([
                rewrite('http://localhost:3000/frontend'),
                rewrite('http://localhost:8000/api'),
                rewrite('http://api.localhost:8000/v1'),
                rewrite('ws://localhost:5173/hmr'),
                rewrite('wss://localhost:5173/hmr'),
                rewrite('https://localhost:9443/secure')
              ]);
            })()
            """
        ) as? String

        #expect(
            result == #"["http://bmux-loopback.localtest.me:3000/frontend","http://bmux-loopback.localtest.me:8000/api","http://api.bmux-loopback.localtest.me:8000/v1","ws://bmux-loopback.localtest.me:5173/hmr","wss://localhost:5173/hmr","https://localhost:9443/secure"]"#
        )
    }
}
