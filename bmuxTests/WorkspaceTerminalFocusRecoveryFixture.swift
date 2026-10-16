import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a focused terminal graph, its queued focus delivery, and native teardown.
@MainActor
final class WorkspaceTerminalFocusRecoveryFixture {
    let panel: TerminalPanel
    let window: NSWindow
    private let app: AppDelegate
    private var manager: TabManager?
    private var windowID: UUID?
    private var peers: [TerminalPanel] = []

    static func run(
        dock: Bool,
        _ body: @MainActor (WorkspaceTerminalFocusRecoveryFixture) async throws -> Void
    ) async throws {
        let fixture = try WorkspaceTerminalFocusRecoveryFixture(dock: dock)
        defer { fixture.close() }
        try await body(fixture)
    }

    private init(dock: Bool) throws {
        app = try #require(AppDelegate.shared, "Expected the app-host composition owner")
        panel = Self.makePanel(dock: dock)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        if !dock {
            let transfer = Workspace.DetachedSurfaceTransfer(
                sourceWorkspaceId: panel.surface.tabId, panelId: panel.id, panel: panel,
                title: panel.displayTitle, icon: panel.displayIcon, iconImageData: nil,
                kind: "terminal", isLoading: false, isPinned: false,
                directory: nil, directoryIsTrustedRemoteReport: false, directoryDisplayLabel: nil,
                ttyName: nil, cachedTitle: nil, customTitle: nil, customTitleSource: nil,
                manuallyUnread: false, restoredUnreadIndicator: nil, restorableAgent: nil,
                restorableAgentResumeState: nil, restoredResumeSessionWorkingDirectory: nil,
                resumeBinding: nil, agentRuntime: nil, isRemoteTerminal: false,
                remoteRelayPort: nil, remotePTYSessionID: nil, remoteCleanupConfiguration: nil
            )
            let workspace = Workspace(initialDetachedSurface: transfer)
            let manager = TabManager(autoWelcomeIfNeeded: false)
            manager.tabs.forEach { $0.teardownRemoteConnection(); $0.teardownAllPanels() }
            manager.tabs = [workspace]
            manager.selectedTabId = workspace.id
            self.manager = manager
            windowID = app.registerMainWindowContextForTesting(tabManager: manager)
            workspace.focusPanel(panel.id, trigger: .terminalFirstResponder)
        }
    }

    func makeMainPeer() -> TerminalPanel {
        let peer = Self.makePanel(dock: false)
        peers.append(peer)
        return peer
    }

    func attach(_ panel: TerminalPanel, visible: Bool) throws {
        let content = try #require(window.contentView)
        panel.hostedView.frame = content.bounds
        content.addSubview(panel.hostedView)
        panel.hostedView.setVisibleInUI(visible)
        panel.hostedView.setActive(true)
        content.layoutSubtreeIfNeeded()
        panel.hostedView.layoutSubtreeIfNeeded()
    }

    func prepare(visible: Bool) async throws {
        if let manager {
            try #require(app.tabManagerFor(tabId: panel.workspaceId) === manager)
        }
        try attach(panel, visible: visible)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        try await deliverQueuedFocus(phase: "prepare")
    }

    func deliverQueuedFocus(phase: String = #function, line: UInt = #line) async throws {
        let start = ContinuousClock.now
        let deadline = start.advanced(by: .milliseconds(50))
        let (events, signal) = AsyncStream<Delivery>.makeStream(bufferingPolicy: .bufferingOldest(1))
        defer { signal.finish() }
        // Preserve producer arrival even if the async consumer resumes after the deadline.
        DispatchQueue.main.async { signal.yield(.producer(.now)); signal.finish() }
        let delivery = await withTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { await Self.expireDelivery(at: deadline, signal: signal) }
            var iterator = events.makeAsyncIterator()
            return await iterator.next()
        }
        try Task.checkCancellation()
        guard let delivery else { throw CancellationError() }
        let arrival: ContinuousClock.Instant
        let source: String
        switch delivery {
        case .producer(let timestamp):
            if timestamp < deadline { return }
            arrival = timestamp
            source = "producer"
        case .deadline(let timestamp):
            arrival = timestamp
            source = "deadline"
        case .failed(let error):
            throw error
        }
        throw Failure.focusDeliveryTimedOut(
            phase: phase, line: line, source: source,
            arrivalMilliseconds: Self.milliseconds(start.duration(to: arrival)),
            observedMilliseconds: Self.milliseconds(start.duration(to: .now))
        )
    }

    private static func expireDelivery(
        at deadline: ContinuousClock.Instant,
        signal: AsyncStream<Delivery>.Continuation
    ) async {
        // The original 50ms failure bound is unchanged; the group cancels and joins this timer.
        do { try await ContinuousClock().sleep(until: deadline) }
        catch is CancellationError { return }
        catch {
            signal.yield(.failed(error))
            signal.finish()
            return
        }
        // Serialize deadline publication with the native MainActor producer, not its consumer.
        signal.yield(.deadline(.now))
        signal.finish()
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    private enum Delivery: Sendable {
        case producer(ContinuousClock.Instant)
        case deadline(ContinuousClock.Instant)
        case failed(any Error)
    }

    private static func makePanel(dock: Bool) -> TerminalPanel {
        let surface = TerminalSurface(
            tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil,
            focusPlacement: dock ? .rightSidebarDock : .workspace,
            manualIO: true, manualInputHandler: { _ in }
        )
        return TerminalPanel(workspaceId: surface.tabId, surface: surface)
    }

    private func close() {
        for panel in [panel] + peers {
            panel.surface.beginPortalCloseLifecycle(reason: "focus-recovery-fixture.cleanup")
            panel.surface.releaseSurfaceForTesting()
            panel.surface.teardownSurface()
            panel.hostedView.removeFromSuperview()
        }
        if let windowID { app.unregisterMainWindowContextForTesting(windowId: windowID) }
        manager?.tabs.forEach { $0.teardownRemoteConnection(); $0.teardownAllPanels() }
        window.contentView = nil
        window.close()
    }

    private enum Failure: Error, CustomStringConvertible {
        case focusDeliveryTimedOut(
            phase: String, line: UInt, source: String,
            arrivalMilliseconds: Double, observedMilliseconds: Double
        )

        var description: String {
            switch self {
            case let .focusDeliveryTimedOut(phase, line, source, arrival, observed):
                return "event=focus_delivery_timeout phase=\(phase) line=\(line) source=\(source) "
                    + "arrival_ms=\(arrival) observed_ms=\(observed) deadline_ms=50"
            }
        }
    }
}
