import Foundation
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns one remote HTML navigation, its native observations, and panel teardown.
@MainActor
final class BrowserRemoteLoopbackBridgeFixture {
    private enum WaitResult: Sendable {
        case ready
        case deadline(Duration)
    }

    let panel: BrowserPanel
    private let timeout: Duration
    private let startedAt = ContinuousClock.now
    private let loadingEvents = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private var observations: [NSKeyValueObservation] = []
    private var events: [String] = []
    private var omittedEvents = 0
    private var phase = "created"

    init(timeout: Duration = .seconds(2)) {
        self.timeout = timeout
        let workspaceID = UUID()
        panel = BrowserPanel(
            workspaceId: workspaceID,
            isRemoteWorkspace: true,
            remoteWebsiteDataStoreIdentifier: workspaceID
        )
        // WebKit exposes loading/progress only through this native KVO boundary.
        observations = [
            panel.webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.record("loading_changed")
                    self?.loadingEvents.continuation.yield(())
                }
            },
            panel.webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.record("progress_changed") }
            }
        ]
        if let delegate = panel.webView.navigationDelegate as? BrowserNavigationDelegate {
            let started = delegate.didStartProvisionalNavigation
            let committed = delegate.didCommit
            let finished = delegate.didFinish
            let failed = delegate.didFailNavigation
            delegate.didStartProvisionalNavigation = { [weak self] webView in
                started?(webView)
                self?.notePhase("started")
            }
            delegate.didCommit = { [weak self] webView in
                committed?(webView)
                self?.notePhase("committed")
            }
            delegate.didFinish = { [weak self] webView in
                finished?(webView)
                self?.notePhase("finished")
            }
            delegate.didFailNavigation = { [weak self] webView, url in
                failed?(webView, url)
                self?.notePhase("failed")
            }
        }
        record("observing")
    }

    func close() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        loadingEvents.continuation.finish()
        panel.close()
    }

    func load(_ html: String, baseURL: URL) async throws {
        try Task.checkCancellation()
        // Subscribe before loading, without an initial false event from the empty web view.
        panel.webView.loadHTMLString(html, baseURL: baseURL)
        let deadlineStartedAt = ContinuousClock.now
        record("load_returned")
        guard panel.webView.isLoading else { return }
        let stream = loadingEvents.stream
        let timeout = timeout
        let result = try await withThrowingTaskGroup(of: WaitResult.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await self.waitForNativeLoad(stream) }
            group.addTask {
                // Preserve the original two-second failure bound; native events determine readiness.
                try await ContinuousClock().sleep(until: deadlineStartedAt.advanced(by: timeout))
                return WaitResult.deadline(deadlineStartedAt.duration(to: .now))
            }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
        try Task.checkCancellation()
        if case .deadline(let deadlineElapsed) = result {
            // Preserve the original failure-then-JavaScript assertion flow, with owned phase evidence.
            let diagnostic = "browser_remote_loopback_load_timeout deadline_elapsed=\(deadlineElapsed) "
                + "\(snapshot("failure_snapshot")) omitted_events=\(omittedEvents) "
                + "events=[\(events.joined(separator: "; "))]"
            Issue.record(Comment(rawValue: diagnostic))
        }
    }

    private func waitForNativeLoad(_ stream: AsyncStream<Void>) async throws -> WaitResult {
        for await _ in stream {
            try Task.checkCancellation()
            if !panel.webView.isLoading { return .ready }
        }
        throw CancellationError()
    }

    private func notePhase(_ value: String) {
        phase = value
        record("navigation_\(value)")
    }

    private func record(_ event: String) {
        guard events.count < 64 else {
            omittedEvents += 1
            return
        }
        events.append(snapshot(event))
    }

    private func snapshot(_ event: String) -> String {
        let webView = panel.webView
        let urlClass: String
        if let url = webView.url {
            urlClass = url.scheme == "about" ? "about" : (
                url.host == "bmux-loopback.localtest.me" ? "owned_alias" : "other"
            )
        } else {
            urlClass = "none"
        }
        return "event=\(event) elapsed=\(startedAt.duration(to: .now)) phase=\(phase) "
            + "native_loading=\(webView.isLoading) progress=\(webView.estimatedProgress) url_class=\(urlClass)"
    }
}
