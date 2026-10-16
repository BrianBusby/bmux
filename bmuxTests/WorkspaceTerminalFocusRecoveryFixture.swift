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
    private var isClosed = false

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

    func prepareFindTerminalRestore(searchState: TerminalSurface.SearchState) async throws {
        try await prepare(visible: true)
        try await NativeMainQueueDelivery(duration: .seconds(1)).deliver {
            panel.surface.searchState = searchState
            panel.hostedView.setSearchOverlay(searchState: searchState)
        }
        let overlay = try #require(panel.hostedView.debugSearchOverlayHostingViewForTesting())
        overlay.layoutSubtreeIfNeeded()
        let field = try #require(findEditableTextField(in: overlay))
        // Complete initial Find autofocus before establishing the terminal-restoration intent.
        try await TerminalSearchFieldFocusObservation(duration: .seconds(1)).wait(of: field, in: window)
        panel.hostedView.preparePanelFocusIntentForActivation(.surface)
    }

    func deliverQueuedFocus(phase: String = #function, line: UInt = #line) async throws {
        try await NativeMainQueueDelivery(duration: .seconds(1)).deliver(phase: phase, line: line)
    }

    func setSurfaceGeometry(_ size: NSSize) {
        // The native host owns child sizing; queued layout must preserve this test precondition.
        panel.hostedView.frame.size = size
        panel.hostedView.reconcileGeometryNow()
        panel.hostedView.surfaceView.frame = NSRect(origin: .zero, size: size)
    }

    func revealWithTinySurface() async throws -> TerminalFocusDeferralObservation {
        var observation: TerminalFocusDeferralObservation?
        try await NativeMainQueueDelivery(duration: .seconds(1)).deliver {
            // Native reveal refreshes layout synchronously before queueing automatic focus.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isClosed else { return }
                self.panel.hostedView.surfaceView.frame = .zero
            }
            panel.hostedView.setVisibleInUI(true)
            // Capture actual callback effects before a later AppKit layout can resize the child.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isClosed else { return }
                observation = TerminalFocusDeferralObservation(
                    firstResponder: self.panel.hostedView.isSurfaceViewFirstResponder(),
                    hostDesiredFocus: self.panel.hostedView.debugRenderStats().desiredFocus,
                    surfaceDesiredFocus: self.panel.surface.debugDesiredFocusState(),
                    surfaceSize: self.panel.hostedView.surfaceView.frame.size,
                    hostSize: self.panel.hostedView.frame.size
                )
            }
        }
        return try #require(observation)
    }

    private func findEditableTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for subview in view.subviews {
            if let field = findEditableTextField(in: subview) { return field }
        }
        return nil
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
        isClosed = true
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
}
