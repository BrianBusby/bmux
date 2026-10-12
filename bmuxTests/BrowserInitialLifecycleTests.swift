import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct BrowserInitialLifecycleTests {
    @Test(arguments: [false, true])
    func deferredNavigationIsReportedBeforeVisibilityChanges(useRequest: Bool) throws {
        let url = try #require(URL(string: "https://example.test/roof-inspection"))
        let panel = BrowserPanel(
            workspaceId: UUID(),
            initialURL: useRequest ? nil : url,
            initialRequest: useRequest ? URLRequest(url: url) : nil,
            renderInitialNavigation: false
        )
        defer { panel.close() }

        #expect(panel.currentURL == url)
        #expect(!panel.shouldRenderWebView)
        #expect(!panel.isShowingNewTabPage)
        #expect(panel.webView.url == nil)
        #expect(panel.webViewLifecycleState == .deferredURL)
        #expect(panel.webViewLifecycleTopPayload()["state"] as? String == "deferred_url")

        panel.noteWebViewVisibility(true, reason: "test.initialVisible")
        #expect(panel.webViewLifecycleState == .deferredURL)
        panel.noteWebViewVisibility(false, reason: "test.initialHidden")
        #expect(panel.webViewLifecycleState == .deferredURL)
        #expect(panel.currentURL == url)
        #expect(panel.webView.url == nil)
    }

    @Test(arguments: [false, true])
    func emptyPanelStartsAsNewTab(renderInitialNavigation: Bool) {
        let panel = BrowserPanel(workspaceId: UUID(), renderInitialNavigation: renderInitialNavigation)
        defer { panel.close() }

        #expect(panel.currentURL == nil)
        #expect(!panel.shouldRenderWebView)
        #expect(panel.isShowingNewTabPage)
        #expect(panel.webViewLifecycleState == .newTab)
        #expect(panel.webViewLifecycleTopPayload()["state"] as? String == "new_tab")
    }
}
