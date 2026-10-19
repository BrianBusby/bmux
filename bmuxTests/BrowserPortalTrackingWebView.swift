import AppKit
import WebKit

@MainActor
final class BrowserPortalTrackingWebView: WKWebView {
    private(set) var displayIfNeededCount = 0
    private(set) var reattachRenderingStateCount = 0
    private let displayEvents = AsyncStream<CGRect>.makeStream(bufferingPolicy: .bufferingNewest(1))

    override func displayIfNeeded() {
        displayIfNeededCount += 1
        super.displayIfNeeded()
        if let slot = superview {
            displayEvents.continuation.yield(slot.frame)
        }
    }

    @objc(_enterInWindow)
    func recordEnterInWindow() {
        reattachRenderingStateCount += 1
    }

    @objc(_endDeferringViewInWindowChangesSync)
    func recordEndDeferringViewInWindowChangesSync() {
        reattachRenderingStateCount += 1
    }

    func finishObservingDisplays() {
        displayEvents.continuation.finish()
    }

    func waitForDisplayedWidth(_ width: CGFloat, timeout: Duration) async -> Bool {
        let frames = displayEvents.stream
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await frame in frames {
                    if abs(frame.width - width) < 0.5 { return true }
                }
                return false
            }
            group.addTask {
                // Preserve the old 250ms failure bound while awaiting real display delivery.
                do { try await ContinuousClock().sleep(for: timeout) } catch { return false }
                return false
            }
            defer { group.cancelAll() }
            return await group.next() ?? false
        }
    }
}
