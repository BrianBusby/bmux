import Foundation
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Records only this fixture's readiness signals; it never determines readiness.
@MainActor
final class BrowserNavigationReadinessDiagnostics {
    let startedAt = ContinuousClock.now
    private let panel: BrowserPanel
    private var events: [String] = []
    private var omittedEventCount = 0
    private var webViewObservations: [NSKeyValueObservation] = []

    init(panel: BrowserPanel) {
        self.panel = panel
        // WebKit exposes these independent readiness dependencies only through KVO.
        webViewObservations = [
            panel.webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.record("webview_loading") }
            },
            panel.webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.record("webview_progress") }
            },
            panel.webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.record("webview_url") }
            }
        ]
        record("observation_started")
    }

    func stop() {
        webViewObservations.forEach { $0.invalidate() }
        webViewObservations.removeAll()
    }

    func record(_ event: String, loading: Bool? = nil) {
        guard events.count < 64 else {
            omittedEventCount += 1
            return
        }
        events.append(snapshot(event: event, loading: loading))
    }

    func describeFailure(_ error: NSError) -> NSError {
        var details = error.userInfo
        let deadlineElapsed = details["deadline_elapsed"] as? String ?? "unavailable"
        details[NSLocalizedDescriptionKey] = "browser_navigation_readiness_timeout "
            + "deadline_elapsed=\(deadlineElapsed) "
            + "\(snapshot(event: "failure_snapshot")) omitted_events=\(omittedEventCount) "
            + "events=[\(events.joined(separator: "; "))]"
        return NSError(domain: error.domain, code: error.code, userInfo: details)
    }

    private func snapshot(event: String, loading: Bool? = nil) -> String {
        let webView = panel.webView
        let urlClass: String
        if let url = webView.url {
            urlClass = url.absoluteString == "about:blank" ? "about_blank" : "other"
        } else {
            urlClass = "none"
        }
        return "event=\(event) elapsed=\(startedAt.duration(to: .now)) "
            + "model_loading=\(panel.isLoading) signal_loading=\(loading.map(String.init) ?? "none") "
            + "webview_loading=\(webView.isLoading) progress=\(webView.estimatedProgress) url_class=\(urlClass)"
    }
}
