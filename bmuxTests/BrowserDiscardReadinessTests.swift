import Combine
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct BrowserDiscardReadinessTests {
    @Test
    func discardReplacesHiddenWebViewAndRestoresOnDemand() async throws {
        let discardedAt = Date(timeIntervalSince1970: 200)
        let panel = BrowserPanel(
            workspaceId: UUID(),
            initialURL: URL(string: "about:blank"),
            isRemoteWorkspace: false
        )
        defer { panel.close() }

        try await waitForNavigation(panel, timeout: .seconds(1))

        panel.noteWebViewVisibility(false, reason: "test.hidden", now: discardedAt)
        let originalWebView = panel.webView

        #expect(panel.discardHiddenWebViewForMemory(reason: "test.discard", now: discardedAt))
        #expect(panel.webView !== originalWebView)
        #expect(!panel.shouldRenderWebView)
        #expect(panel.webViewLifecycleState == .discarded)

        let discardedPayload = panel.webViewLifecycleTopPayload(now: discardedAt)
        #expect(discardedPayload["state"] as? String == "discarded")
        #expect(discardedPayload["last_discard_reason"] as? String == "test.discard")
        #expect(discardedPayload["discarded_at"] as? String != nil)

        // Observe the legacy publisher synchronously so transient states cannot be dropped.
        var observedStates: [BrowserWebViewLifecycleState] = []
        let cancellable = panel.$webViewLifecycleState.sink { state in
            observedStates.append(state)
        }
        defer { cancellable.cancel() }

        #expect(panel.restoreDiscardedWebViewIfNeeded(reason: "test.restore"))
        #expect(panel.shouldRenderWebView)
        #expect(panel.webViewLifecycleState == .liveHidden)
        #expect(!observedStates.contains(.newTab), "Restore emitted unexpected states: \(observedStates)")

        panel.noteWebViewVisibility(true, reason: "test.visible")
        #expect(panel.webViewLifecycleState == .liveVisible)
    }

    @Test
    func restoredHistoryBackDoesNotEmitNewTabLifecycleState() async throws {
        let discardedAt = Date(timeIntervalSince1970: 300)
        let panel = BrowserPanel(
            workspaceId: UUID(),
            initialURL: URL(string: "about:blank"),
            isRemoteWorkspace: false
        )
        defer { panel.close() }

        try await waitForNavigation(panel, timeout: .seconds(1))

        panel.restoreSessionNavigationHistory(
            backHistoryURLStrings: ["https://example.test/back"],
            forwardHistoryURLStrings: [],
            currentURLString: "https://example.test/current"
        )
        #expect(panel.canGoBack)

        panel.noteWebViewVisibility(false, reason: "test.hidden", now: discardedAt)
        #expect(panel.discardHiddenWebViewForMemory(reason: "test.discard", now: discardedAt))
        #expect(panel.webViewLifecycleState == .discarded)

        // Observe the legacy publisher synchronously so transient states cannot be dropped.
        var observedStates: [BrowserWebViewLifecycleState] = []
        let cancellable = panel.$webViewLifecycleState.sink { state in
            observedStates.append(state)
        }
        defer { cancellable.cancel() }

        panel.goBack()

        #expect(!observedStates.contains(.newTab), "Back restore emitted unexpected states: \(observedStates)")
        #expect(panel.webViewLifecycleState == .liveHidden)
    }

    private func waitForNavigation(_ panel: BrowserPanel, timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await loading in panel.$isLoading.values {
                    if !loading,
                       !panel.webView.isLoading,
                       panel.webView.estimatedProgress == 1,
                       panel.webView.url != nil { return }
                }
                throw CancellationError()
            }
            group.addTask {
                // Deadline bounds failure; navigation events determine readiness.
                try await Task.sleep(for: timeout)
                throw NSError(domain: "BrowserNavigationReadiness", code: 1)
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }
}
