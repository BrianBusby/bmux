import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a pane's native responder graph and its actual main-window shortcut context.
@MainActor
final class FileExplorerShortcutRoutingFixture {
    let app: AppDelegate
    let manager: TabManager
    let window: NSWindow
    let table: FileExplorerSearchResultsTableView
    let childButton: NSButton
    private let previousApp: AppDelegate?
    private let previousActiveManager: TabManager?

    init() {
        _ = NSApplication.shared
        previousApp = AppDelegate.shared
        previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        app = AppDelegate()
        manager = TabManager(autoWelcomeIfNeeded: false)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        table = FileExplorerSearchResultsTableView(frame: NSRect(x: 0, y: 0, width: 240, height: 180))
        childButton = NSButton(frame: NSRect(x: 8, y: 8, width: 80, height: 28))
        table.fileExplorerPanelPlacement = .pane
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.isEditable = false
        table.addTableColumn(column)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 240, height: 180))
        scroll.documentView = table
        let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
        content.addSubview(scroll)
        window.contentView = content

        let id = UUID()
        let sidebar = SidebarState()
        let selection = SidebarSelectionState()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(id.uuidString)")
        manager.window = window
        manager.windowId = id
        app.tabManager = manager
        app.sidebarState = sidebar
        app.sidebarSelectionState = selection
        // Compose the real route without registration's listener and session-save side effects.
        app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
            windowId: id, tabManager: manager, sidebarState: sidebar,
            sidebarSelectionState: selection, fileExplorerState: nil, bmuxConfigStore: nil, window: window)
    }

    func event(shortcut: StoredShortcut) throws -> NSEvent {
        let keyCode = try #require(shortcut.firstStroke.resolvedKeyCode())
        return try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: shortcut.modifierFlags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: shortcut.menuItemKeyEquivalent ?? shortcut.key,
            charactersIgnoringModifiers: shortcut.menuItemKeyEquivalent ?? shortcut.key,
            isARepeat: false, keyCode: keyCode))
    }

    func close() {
        table.onCommit = nil
        for workspace in manager.tabs {
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
        }
        app.mainWindowContexts.removeAll()
        app.tabManager = nil
        manager.window = nil
        window.contentView = nil
        window.close()
        TerminalController.shared.setActiveTabManager(previousActiveManager)
        AppDelegate.shared = previousApp
        if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
    }
}
