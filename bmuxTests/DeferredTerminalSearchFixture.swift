import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the registered terminal and native window used by deferred search attachment.
@MainActor
final class DeferredTerminalSearchFixture {
    let panel: TerminalPanel
    let window: NSWindow
    private let app: AppDelegate
    private var manager: TabManager?
    private var windowID: UUID?

    init() throws {
        app = try #require(AppDelegate.shared, "Expected the app-host composition owner")
        panel = Self.makePanel()
        window = OwnedKeyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
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

    func present() throws {
        let content = try #require(window.contentView)
        panel.hostedView.frame = content.bounds
        panel.hostedView.autoresizingMask = [.width, .height]
        content.addSubview(panel.hostedView)
        panel.hostedView.setVisibleInUI(true)
        panel.hostedView.setActive(true)
        content.layoutSubtreeIfNeeded()
        panel.hostedView.layoutSubtreeIfNeeded()
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
    }

    private static func makePanel() -> TerminalPanel {
        let surface = TerminalSurface(
            tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil,
            focusPlacement: .workspace,
            manualIO: true, manualInputHandler: { _ in }
        )
        return TerminalPanel(workspaceId: surface.tabId, surface: surface)
    }

    func close() {
        panel.surface.beginPortalCloseLifecycle(reason: "deferred-search-fixture.cleanup")
        panel.surface.releaseSurfaceForTesting()
        panel.surface.teardownSurface()
        panel.hostedView.removeFromSuperview()
        if let windowID { app.unregisterMainWindowContextForTesting(windowId: windowID) }
        manager?.tabs.forEach { $0.teardownRemoteConnection(); $0.teardownAllPanels() }
        window.contentView = nil
        window.close()
    }
}

@MainActor private final class OwnedKeyWindow: NSWindow { override var isKeyWindow: Bool { true } }
