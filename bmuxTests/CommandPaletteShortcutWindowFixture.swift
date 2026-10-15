import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a palette responder and routing context without starting a full application window.
@MainActor
final class CommandPaletteShortcutWindowFixture {
    let app: AppDelegate
    let window: NSWindow
    private(set) var observedDeltas: [Int] = []
    private(set) var observedWindow: NSWindow?
    private(set) var notificationCount = 0
    private let manager: TabManager
    private let overlay: NSView
    private let editor: NSTextView
    private let previousApp: AppDelegate?
    private let previousActiveManager: TabManager?
    private var notificationToken: NSObjectProtocol?

    init() {
        _ = NSApplication.shared
        previousApp = AppDelegate.shared
        previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        app = AppDelegate()
        manager = TabManager(autoWelcomeIfNeeded: false)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        overlay = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    }

    func prepare() throws {
        let windowID = UUID()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowID.uuidString)")
        manager.window = window
        manager.windowId = windowID
        app.tabManager = manager
        // Compose the actual route without registration's listeners or window activation.
        app.mainWindowContexts[ObjectIdentifier(window)] = AppDelegate.MainWindowContext(
            windowId: windowID, tabManager: manager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
            bmuxConfigStore: nil, window: window
        )
        overlay.identifier = commandPaletteOverlayContainerIdentifier
        overlay.alphaValue = 1
        overlay.isHidden = false
        try #require(window.contentView).addSubview(overlay)
        editor.isFieldEditor = true
        overlay.addSubview(editor)
        try #require(window.makeFirstResponder(editor))
        try #require(editor.isFieldEditor)
        try #require(!editor.hasMarkedText())
        notificationToken = NotificationCenter.default.addObserver(
            forName: .commandPaletteMoveSelection, object: nil, queue: nil
        ) { [weak self] notification in
            // The real handler posts synchronously on MainActor; no hook crosses suspension.
            MainActor.assumeIsolated {
                self?.notificationCount += 1
                self?.observedWindow = notification.object as? NSWindow
                if let delta = notification.userInfo?["delta"] as? Int {
                    self?.observedDeltas.append(delta)
                }
            }
        }
    }

    func event(_ key: String, modifiers: NSEvent.ModifierFlags, keyCode: UInt16) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: key, charactersIgnoringModifiers: key,
            isARepeat: false, keyCode: keyCode
        ))
    }

    /// Synchronous defer cleanup covers failed preparation and restores the previous runtime graph.
    func close() {
        if let notificationToken { NotificationCenter.default.removeObserver(notificationToken) }
        app.clearConfiguredShortcutChordState()
        app.setCommandPaletteVisible(false, for: window)
        editor.removeFromSuperview()
        overlay.removeFromSuperview()
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
