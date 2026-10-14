import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a retained rendering window and cancellable WebKit completion registrations.
@MainActor
final class MarkdownRenderTestFixture: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    private let window: NSWindow
    private let navigationTimeout: Duration
    let imageTimeout: Duration
    let buttonTimeout: Duration
    private var expectedNavigation: WKNavigation?
    private var activeID: String?
    private var completion: AsyncStream<Result<String, Error>>.Continuation?
    private let messageName = "bmuxRenderingFixture"

    init(
        webView: WKWebView,
        navigationTimeout: Duration = .seconds(5),
        imageTimeout: Duration = .seconds(3),
        buttonTimeout: Duration = .seconds(8)
    ) {
        self.webView = webView
        self.navigationTimeout = navigationTimeout
        self.imageTimeout = imageTimeout
        self.buttonTimeout = buttonTimeout
        window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        // The fixture, not NSWindow.close(), owns the final release.
        window.isReleasedWhenClosed = false
        super.init()
        window.contentView = webView
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(WeakMarkdownScriptMessageHandler(self), name: messageName)
        window.orderFrontRegardless()
    }

    func close() {
        cancelDOMObservation()
        completion?.finish()
        completion = nil
        activeID = nil
        expectedNavigation = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageName)
        webView.navigationDelegate = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        window.contentView = nil
        window.orderOut(nil)
        window.close()
    }

    func loadShell(baseURL: URL) async throws {
        _ = try await operation(deadline: ContinuousClock.now.advanced(by: navigationTimeout)) { _ in
            expectedNavigation = webView.loadHTMLString(
                MarkdownViewerAssets.shared.shellHTML(isDark: true), baseURL: baseURL
            )
            if expectedNavigation == nil { finish(.failure(Failure.navigationNotStarted)) }
        }
    }

    func renderMarkdown(_ markdown: String) async throws {
        let data = try JSONSerialization.data(withJSONObject: [markdown])
        let literal = try #require(String(data: data, encoding: .utf8))
        _ = try await webView.evaluateJavaScript("window.__bmuxRenderMarkdown(\(literal)[0]);")
    }

    func observeDOM(snapshot: String, predicate: String, deadline: ContinuousClock.Instant) async throws -> String {
        try await operation(deadline: deadline) { id in
            let remaining = ContinuousClock.now.duration(to: deadline)
            let milliseconds = max(0, Double(remaining.components.seconds) * 1000 + Double(remaining.components.attoseconds) / 1e15)
            let script = observationScript(id: id, snapshot: snapshot, predicate: predicate, milliseconds: milliseconds)
            // WebKit's completion callback is confined to this async operation boundary.
            webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error, self?.activeID == id { self?.finish(.failure(error)) }
            }
        }
    }

    private func operation(
        deadline: ContinuousClock.Instant,
        start: (String) -> Void
    ) async throws -> String {
        try #require(activeID == nil, "Rendering fixture operations must not overlap")
        let id = UUID().uuidString
        let events = AsyncStream<Result<String, Error>>.makeStream(bufferingPolicy: .bufferingNewest(1))
        activeID = id
        completion = events.continuation
        defer {
            cancelDOMObservation()
            completion?.finish()
            completion = nil
            activeID = nil
            expectedNavigation = nil
        }
        start(id)
        return try await withThrowingTaskGroup(of: String.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await result in events.stream { return try result.get() }
                throw CancellationError()
            }
            group.addTask {
                // Original phase deadline; cancellation joins the timer without polling WebKit.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.deadlineExceeded
            }
            return try await group.next() ?? ""
        }
    }

    private func cancelDOMObservation() {
        guard let activeID else { return }
        // This queues cancellation on the same page before any subsequent evaluation.
        // The JS phase timer/pagehide also cleans up; close releases the page if its process has died.
        webView.evaluateJavaScript(
            "window.__bmuxFixtureObservers && window.__bmuxFixtureObservers['\(activeID)'] && window.__bmuxFixtureObservers['\(activeID)']();",
            completionHandler: nil
        )
    }

    private func finish(_ result: Result<String, Error>) {
        completion?.yield(result)
        completion?.finish()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === expectedNavigation else { return }
        finish(.success(""))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if activeID != nil, navigation !== expectedNavigation { finish(.failure(Failure.navigationReplaced)) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(.failure(Failure.webContentProcessTerminated))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == messageName,
              let body = message.body as? [String: String], body["id"] == activeID else { return }
        if let error = body["error"] { finish(.failure(Failure.domObservation(error))) }
        else if let json = body["json"] { finish(.success(json)) }
        else { finish(.failure(Failure.invalidDOMResult)) }
    }

    private enum Failure: Error {
        case navigationNotStarted, navigationReplaced, webContentProcessTerminated
        case deadlineExceeded, invalidDOMResult, domObservation(String)
    }
}
