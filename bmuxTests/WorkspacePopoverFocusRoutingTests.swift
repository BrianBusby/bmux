import AppKit
import BmuxTerminal
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized) struct WorkspacePopoverFocusRoutingTests {
    @Test func childResponderChangeGrantsOnlyRegisteredPopoverOwnership() throws {
        try withPopoverContext { app, _, parent, child, host, responder in
            let owner = try #require(app.keyboardFocusCoordinator(for: parent)?.workspaceChromeFocusOwner)
            owner.register(host, scope: .filterPopover, in: parent)
            app.syncKeyboardFocusAfterFirstResponderChange(in: child)
            #expect(owner.owns(responder, in: parent))
            let parentResponder = try #require(parent.firstResponder)
            #expect(!owner.owns(parentResponder, in: parent))

            let unrelated = NSTextView(frame: .zero)
            child.contentView?.addSubview(unrelated)
            #expect(child.makeFirstResponder(unrelated))
            app.syncKeyboardFocusAfterFirstResponderChange(in: child)
            #expect(!owner.owns(responder, in: parent))
            #expect(!owner.owns(unrelated, in: parent))
        }
    }

    @Test func escapeInRegisteredPopoverLeavesTerminalFindOpen() throws {
        try withPopoverContext { app, manager, parent, child, host, responder in
            let owner = try #require(app.keyboardFocusCoordinator(for: parent)?.workspaceChromeFocusOwner)
            owner.register(host, scope: .filterPopover, in: parent)
            // Isolate Escape routing from the separate responder-change regression.
            owner.synchronize(responder: responder, in: parent)
            #expect(owner.owns(responder, in: parent))
            let panel = try #require(manager.selectedTerminalPanel)
            panel.searchState = TerminalSurface.SearchState(needle: "")
            defer { panel.searchState = nil }
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: child.windowNumber, context: nil, characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
            ))
            #expect(event.window === child)
            #expect(!bmuxCloseFocusedTerminalFindForEscape(event: event, appDelegate: app))
            #expect(panel.searchState != nil)
            #expect(child.firstResponder === responder)
        }
    }

    private func withPopoverContext(
        body: (AppDelegate, TabManager, NSWindow, NSWindow, NSView, NSTextView) throws -> Void
    ) throws {
        _ = NSApplication.shared
        let previousApp = AppDelegate.shared
        let previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        let app = AppDelegate()
        let manager = TabManager(autoWelcomeIfNeeded: false)
        let parent = makeWindow()
        let child = makeWindow()
        let windowId = UUID()
        parent.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowId.uuidString)")
        manager.windowId = windowId
        manager.window = parent
        app.tabManager = manager
        // Compose the existing context directly, as the test support does, avoiding
        // registerMainWindow's socket listener/session-save side effects.
        app.mainWindowContexts[ObjectIdentifier(parent)] = AppDelegate.MainWindowContext(
            windowId: windowId, tabManager: manager, sidebarState: SidebarState(),
            sidebarSelectionState: SidebarSelectionState(), fileExplorerState: nil,
            bmuxConfigStore: nil, window: parent
        )
        defer {
            for workspace in manager.tabs { for panel in workspace.panels.values { panel.close() } }
            child.parent?.removeChildWindow(child)
            child.contentView = nil
            parent.contentView = nil
            child.orderOut(nil)
            parent.orderOut(nil)
            app.mainWindowContexts.removeAll()
            app.tabManager = nil
            TerminalController.shared.setActiveTabManager(previousActiveManager)
            AppDelegate.shared = previousApp
            if let previousApp { GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp) }
        }
        let parentResponder = NSTextView(frame: .zero)
        parent.contentView?.addSubview(parentResponder)
        #expect(parent.makeFirstResponder(parentResponder))
        let host = NSView(frame: child.contentView?.bounds ?? .zero)
        let responder = NSTextView(frame: host.bounds)
        child.contentView?.addSubview(host)
        host.addSubview(responder)
        parent.addChildWindow(child, ordered: .above)
        #expect(child.makeFirstResponder(responder))
        #expect(parent.firstResponder === parentResponder)
        #expect(child.firstResponder === responder)
        try body(app, manager, parent, child, host, responder)
    }

    private func makeWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                 styleMask: [.titled], backing: .buffered, defer: false)
    }
}
