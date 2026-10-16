import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct MainWindowFocusRedrawTests {
    @Test func testKeyRegainInvalidatesRootContentView() {
        _ = NSApplication.shared

        let previousAppDelegate = AppDelegate.shared
        let previousActiveManager = TerminalController.shared.activeTabManagerForCallerNotification()
        let appDelegate = AppDelegate()
        defer {
            TerminalController.shared.setActiveTabManager(previousActiveManager)
            AppDelegate.shared = previousAppDelegate
            if let previousAppDelegate {
                GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousAppDelegate)
            }
        }
        let tabManager = TabManager(autoWelcomeIfNeeded: false)
        defer { tabManager.tabs.forEach { $0.teardownAllPanels() } }
        let windowId = appDelegate.registerMainWindowContextForTesting(tabManager: tabManager)
        defer {
            appDelegate.unregisterMainWindowContextForTesting(windowId: windowId)
        }

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        let splitView = NSSplitView(frame: contentView.bounds)
        splitView.isVertical = true
        splitView.autoresizingMask = [.width, .height]
        splitView.dividerStyle = .thin

        let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 420))
        let main = NSView(frame: NSRect(x: 221, y: 0, width: 419, height: 420))
        splitView.addArrangedSubview(sidebar)
        splitView.addArrangedSubview(main)
        contentView.addSubview(splitView)
        splitView.setPosition(220, ofDividerAt: 0)

        let window = BmuxMainWindow(
            contentRect: contentView.bounds,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowId.uuidString)")
        window.contentView = contentView
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        contentView.layoutSubtreeIfNeeded()
        splitView.adjustSubviews()

        contentView.needsDisplay = false

        appDelegate.handleBmuxWindowResignedKey(
            Notification(name: NSWindow.didResignKeyNotification, object: window)
        )
        appDelegate.handleBmuxWindowBecameKey(
            Notification(name: NSWindow.didBecomeKeyNotification, object: window)
        )

        #expect(
            contentView.needsDisplay,
            "Regaining key focus must invalidate the root content view."
        )
    }
}
