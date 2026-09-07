import AppKit
import Foundation

@MainActor
struct BrowserDevToolsRuntimeServiceDependencies {
    var validateRequiredRuntime: () -> BrowserDevToolsRuntimeOperationResult
    var startSystemProxyObservation: () -> BrowserDevToolsRuntimeOperationResult
    var stopSystemProxyObservation: () -> Void
    var makeAddressBarFocusObserver: (@escaping @MainActor (_ panelId: UUID) -> Void) -> NSObjectProtocol
    var makeAddressBarBlurObserver: (@escaping @MainActor (_ panelId: UUID) -> Void) -> NSObjectProtocol
    var makeWebViewFirstResponderObserver: (@escaping @MainActor (_ notification: Notification) -> Void) -> NSObjectProtocol
    var removeObserver: (_ observer: NSObjectProtocol) -> Void
    var closeAllWebInspectors: () -> Int
    var closeWebInspectorsInWindow: (_ window: NSWindow) -> Int
    var discardPrewarmedWebViews: () -> Void
    var flushBrowserProfileSaves: () -> Void

    static func production() -> BrowserDevToolsRuntimeServiceDependencies {
        BrowserDevToolsRuntimeServiceDependencies(
            validateRequiredRuntime: { .ready },
            startSystemProxyObservation: {
                BrowserSystemProxyWatcher.shared.startObserving()
                    ? .ready
                    : .degraded(reason: "system proxy observation unavailable")
            },
            stopSystemProxyObservation: {
                BrowserSystemProxyWatcher.shared.stopObserving()
            },
            makeAddressBarFocusObserver: { handler in
                NotificationCenter.default.addObserver(
                    forName: .browserDidFocusAddressBar,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let panelId = notification.object as? UUID else { return }
                    MainActor.assumeIsolated {
                        handler(panelId)
                    }
                }
            },
            makeAddressBarBlurObserver: { handler in
                NotificationCenter.default.addObserver(
                    forName: .browserDidBlurAddressBar,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let panelId = notification.object as? UUID else { return }
                    MainActor.assumeIsolated {
                        handler(panelId)
                    }
                }
            },
            makeWebViewFirstResponderObserver: { handler in
                NotificationCenter.default.addObserver(
                    forName: .browserDidBecomeFirstResponderWebView,
                    object: nil,
                    queue: .main
                ) { notification in
                    MainActor.assumeIsolated {
                        handler(notification)
                    }
                }
            },
            removeObserver: { observer in
                NotificationCenter.default.removeObserver(observer)
            },
            closeAllWebInspectors: {
                WebViewInspectorTeardown.closeAllInspectors(in: NSApp.windows)
            },
            closeWebInspectorsInWindow: { window in
                WebViewInspectorTeardown.closeAllInspectors(in: window)
            },
            discardPrewarmedWebViews: {
                BrowserPrewarmedWebViewPool.shared.discard(reason: "runtime-shutdown")
            },
            flushBrowserProfileSaves: {
                BrowserProfileStore.shared.flushPendingSaves()
            }
        )
    }
}
