import AppKit
import WebKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Creates inspector graphs and retained windows; each case explicitly tears down its owned graph.
@MainActor
struct BrowserInspectorTestFixture {
    let panel: BrowserPanel
    let inspector: BrowserInspectorProbe

    init(panel: BrowserPanel? = nil) {
        installBmuxUnitTestInspectorOverride()
        self.panel = panel ?? BrowserPanel(workspaceId: UUID())
        inspector = BrowserInspectorProbe()
        self.panel.webView.bmuxSetUnitTestInspector(inspector)
    }

    func makeWindow(contentRect: NSRect) -> NSWindow {
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        // Swift owns these windows, including when an action closes them before teardown.
        window.isReleasedWhenClosed = false
        return window
    }

    func closeWindow(_ window: NSWindow) {
        window.contentView = nil
        window.orderOut(nil)
        window.close()
    }

    func closePanel() {
        panel.close()
        BrowserWindowPortalRegistry.detach(webView: panel.webView)
        panel.webView.bmuxSetUnitTestInspector(nil)
        panel.webView.removeFromSuperview()
    }

    static func tearDownPanels(manager: TabManager) {
        let browserPanels = manager.tabs.flatMap { workspace in
            workspace.panels.values.compactMap { $0 as? BrowserPanel }
        }
        for workspace in manager.tabs { workspace.teardownAllPanels() }
        for browserPanel in browserPanels {
            BrowserWindowPortalRegistry.detach(webView: browserPanel.webView)
            browserPanel.webView.bmuxSetUnitTestInspector(nil)
            browserPanel.webView.removeFromSuperview()
        }
    }

    /// The existing 2.85-second failure deadline; completion comes only from owner events.
    func waitForTransitions(
        observation: (id: UUID, events: AsyncStream<Void>),
        timeout: Duration = .seconds(2.85),
        until condition: @escaping @MainActor @Sendable () -> Bool
    ) async throws {
        defer { panel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        let panel = panel
        let completed = try await completesBeforeDeadline(timeout: timeout) {
            if panel.debugDeveloperToolsTransitionsAreSettled && condition() { return true }
            for await _ in observation.events {
                if Task.isCancelled { return false }
                if panel.debugDeveloperToolsTransitionsAreSettled && condition() { return true }
            }
            return false
        }
        #expect(completed, "Timed out or closed while waiting for developer-tools transitions")
    }

    func waitForObservationEnd(
        _ observation: (id: UUID, events: AsyncStream<Void>),
        timeout: Duration = .seconds(2.85)
    ) async throws {
        defer { panel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        try await waitForStreamEnd(observation.events, timeout: timeout)
    }

    func waitForStreamEnd(
        _ events: AsyncStream<Void>,
        timeout: Duration = .seconds(2.85)
    ) async throws {
        let completed = try await completesBeforeDeadline(timeout: timeout) {
            for await _ in events {
                if Task.isCancelled { return false }
            }
            return !Task.isCancelled
        }
        #expect(completed, "Expected lifecycle observation to finish")
    }

    private func completesBeforeDeadline(
        timeout: Duration,
        operation: @escaping @MainActor @Sendable () async -> Bool
    ) async throws -> Bool {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask { await operation() }
            group.addTask {
                // A cancellable failure deadline, never a delay used to settle or poll state.
                try await ContinuousClock().sleep(for: timeout)
                return false
            }
            return try await group.next() ?? false
        }
    }

    func findView<T: NSView>(_ type: T.Type, in root: NSView) -> T? {
        if let match = root as? T { return match }
        for subview in root.subviews {
            if let match = findView(type, in: subview) { return match }
        }
        return nil
    }

}
