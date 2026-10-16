import Combine
import Foundation
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct BrowserVisibleNotificationTests {
    /// Repeated appearances must not restore, replace, or re-navigate an already live web view.
    @Test
    func redundantVisibleNotificationsDoNotChurnLiveWebView() async throws {
        let panel = BrowserPanel(
            workspaceId: UUID(),
            initialURL: URL(string: "about:blank")!,
            isRemoteWorkspace: false
        )
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        defer { panel.close() }

        let completed = try await waitForNativeLoad(panel, deadline: deadline)
        #expect(completed && !panel.webView.isLoading, "Timed out waiting for about:blank to finish loading")

        panel.noteWebViewVisibility(true, reason: "test.visible.first")
        #expect(panel.webViewLifecycleState == .liveVisible)
        let webViewAfterFirst = panel.webView
        let instanceIDAfterFirst = panel.webViewInstanceID
        let reasonAfterFirst = panel.webViewLastVisibilityChangeReason
        let changeAtAfterFirst = panel.webViewLastVisibilityChangeAt

        // This existing legacy publisher must be observed synchronously to retain transient churn.
        var observedStates: [BrowserWebViewLifecycleState] = []
        let observation = panel.$webViewLifecycleState.dropFirst().sink { observedStates.append($0) }
        defer { observation.cancel() }
        for index in 0..<32 {
            panel.noteWebViewVisibility(true, reason: "test.visible.spurious-\(index)")
        }

        #expect(panel.webViewLifecycleState == .liveVisible)
        #expect(observedStates.isEmpty, "Redundant visible notes churned lifecycle: \(observedStates)")
        #expect(panel.webView === webViewAfterFirst, "A live webview must not be replaced by redundant visibility notes")
        #expect(panel.webViewInstanceID == instanceIDAfterFirst)
        #expect(panel.webViewLastVisibilityChangeReason == reasonAfterFirst)
        #expect(panel.webViewLastVisibilityChangeAt == changeAtAfterFirst)
    }

    private func waitForNativeLoad(_ panel: BrowserPanel, deadline: ContinuousClock.Instant) async throws -> Bool {
        let webView = panel.webView
        let events = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        // Native WebKit loading exposes this change through KVO; keep the token at this boundary.
        let observation = webView.observe(\.isLoading, options: [.new]) { _, _ in
            events.continuation.yield(())
        }
        defer {
            observation.invalidate()
            events.continuation.finish()
        }
        try Task.checkCancellation()
        // Initial navigation starts in the constructor. Subscribe before checking its current state.
        guard webView.isLoading else { return true }
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await nativeLoadCompleted(events.stream, panel: panel) }
            group.addTask {
                // Preserve the original post-constructor one-second failure bound, without polling.
                try await ContinuousClock().sleep(until: deadline)
                return false
            }
            let result = try await group.next()
            try Task.checkCancellation()
            guard let result else { throw CancellationError() }
            return result
        }
    }

    private func nativeLoadCompleted(_ stream: AsyncStream<Void>, panel: BrowserPanel) async throws -> Bool {
        for await _ in stream {
            try Task.checkCancellation()
            if !panel.webView.isLoading { return true }
        }
        throw CancellationError()
    }

}
