import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a native terminal and its focused workspace only for synchronous mouse dispatch.
@MainActor
final class TerminalSearchOverlayMouseFixture {
    let surface: TerminalSurface
    let window: NSWindow
    var hostedView: GhosttySurfaceScrollView { surface.hostedView }
    private let readiness: TerminalRuntimeReadinessFixture
    private let readinessTimeout: Duration
    private let mountTimeout: Duration

    init(readinessTimeout: Duration, mountTimeout: Duration) {
        self.readinessTimeout = readinessTimeout
        self.mountTimeout = mountTimeout
        surface = TerminalSurface(
            tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil, manualIO: true,
            manualInputHandler: { _ in }
        )
        readiness = TerminalRuntimeReadinessFixture(surface: surface)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
    }

    func prepare() async throws {
        let content = try #require(window.contentView)
        hostedView.frame = content.bounds
        hostedView.autoresizingMask = [.width, .height]
        content.addSubview(hostedView)
        content.layoutSubtreeIfNeeded()
        hostedView.layoutSubtreeIfNeeded()
        if !surface.hasLiveSurface { try await readiness.wait(timeout: readinessTimeout) }
        try Task.checkCancellation()
        _ = try #require(surface.surface)

        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        let deadline = ContinuousClock.now.advanced(by: mountTimeout)
        hostedView.setSearchOverlay(searchState: TerminalSurface.SearchState(needle: "needle"))
        // The native owner queues one mutation; this FIFO event follows its delivery.
        DispatchQueue.main.async { signal.yield(()); signal.finish() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Original mount failure cap, anchored before the native action, never settling.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.mountTimedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
        hostedView.layoutSubtreeIfNeeded()
    }

    func withFocusedWorkspace(_ body: (GhosttyNSView) throws -> Void) throws {
        let previousApp = AppDelegate.shared
        let previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        let app = AppDelegate()
        defer {
            TerminalController.shared.setActiveTabManager(previousActiveManager)
            AppDelegate.shared = previousApp
            if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
        }
        let panel = TerminalPanel(workspaceId: surface.tabId, surface: surface)
        let transfer = Workspace.DetachedSurfaceTransfer(
            sourceWorkspaceId: surface.tabId, panelId: panel.id, panel: panel,
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
        defer {
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
            app.mainWindowContexts.removeAll()
            app.tabManager = nil
            manager.window = nil
        }
        let windowID = UUID()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowID.uuidString)")
        manager.window = window
        manager.windowId = windowID
        app.tabManager = manager
        // Real routing context without registration's listener and session-save side effects.
        app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
            windowId: windowID, tabManager: manager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
            bmuxConfigStore: nil, window: window
        )
        workspace.focusPanel(panel.id)
        hostedView.setVisibleInUI(true)
        hostedView.setActive(true)
        hostedView.moveFocus()
        #expect(workspace.focusedPanelId == surface.id)
        try body(hostedView.surfaceView)
    }

    func mouseEvent(type: NSEvent.EventType, location: NSPoint) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type, location: location, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1.0
        ))
    }

    func close() {
        readiness.close()
        surface.beginPortalCloseLifecycle(reason: "search-overlay-mouse-fixture.cleanup")
        surface.teardownSurface()
        hostedView.removeFromSuperview()
        window.contentView = nil
        window.close()
    }

    private enum Failure: Error { case mountTimedOut }
}
