import AppKit
import Carbon.HIToolbox
import Testing
import WebKit
import ObjectiveC.runtime

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

private var bmuxUnitTestBmuxWebViewKeyDownOverrideInstalled = false
private var bmuxUnitTestBmuxWebViewKeyDownHook: ((BmuxWebView, NSEvent) -> Bool)?

private final class FakeWKInspectorUndoResponderView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

private final class BrowserUndoMenuActionSpy: NSObject {
    private(set) var invoked = false

    @objc func didInvoke(_ sender: Any?) {
        _ = sender
        invoked = true
    }
}

extension BmuxWebView {
    @objc func bmuxUnitTest_keyDown(with event: NSEvent) {
        if bmuxUnitTestBmuxWebViewKeyDownHook?(self, event) == true {
            return
        }
        bmuxUnitTest_keyDown(with: event)
    }
}

private func installBmuxUnitTestBmuxWebViewKeyDownOverride() {
    guard !bmuxUnitTestBmuxWebViewKeyDownOverrideInstalled else { return }

    let originalSelector = #selector(BmuxWebView.keyDown(with:))
    let swizzledSelector = #selector(BmuxWebView.bmuxUnitTest_keyDown(with:))

    guard let originalMethod = class_getInstanceMethod(BmuxWebView.self, originalSelector),
          let swizzledMethod = class_getInstanceMethod(BmuxWebView.self, swizzledSelector) else {
        fatalError("Unable to locate BmuxWebView keyDown methods for swizzling")
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
    bmuxUnitTestBmuxWebViewKeyDownOverrideInstalled = true
}

@Suite(.serialized)
final class BmuxWebViewKeyDownReentryTests {
    @Test
    @MainActor
    func printableOptionTextRoutesToBrowserKeyDownOnce() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "å",
                modifiers: [.option],
                keyCode: 0,
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(keyDownEvents().map(\.keyCode) == [0])
        }
    }

    @Test
    @MainActor
    func printableOptionTextDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "å",
                modifiers: [.option],
                keyCode: 0,
                windowNumber: window.windowNumber
            ))

            let handled = bmuxWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(!handled)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserReturnDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "\r",
                modifiers: [],
                keyCode: 36,
                windowNumber: window.windowNumber
            ))

            let handled = bmuxWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(!handled)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserArrowDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "\u{F701}",
                modifiers: [],
                keyCode: 125,
                windowNumber: window.windowNumber
            ))

            let handled = bmuxWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(!handled)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserUndoRedoFallsBackToBrowserKeyDownWhenWebKitDeclines() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            installBmuxUnitTestWKWebViewPerformKeyEquivalentOverride()

            var performKeyEquivalentEvents: [NSEvent] = []
            bmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView.window === window else { return nil }
                performKeyEquivalentEvents.append(event)
                return false
            }
            defer { bmuxUnitTestWKWebViewPerformKeyEquivalentHook = nil }

            let event = try #require(makeKeyDownEvent(
                key: "z",
                modifiers: [.command],
                keyCode: UInt16(kVK_ANSI_Z),
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(performKeyEquivalentEvents.map(\.keyCode) == [UInt16(kVK_ANSI_Z)])
            #expect(keyDownEvents().map(\.keyCode) == [UInt16(kVK_ANSI_Z)])
        }
    }

    @Test
    @MainActor
    func browserUndoRedoDoesNotRouteDuringWebKitKeyDownReentry() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            installBmuxUnitTestWKWebViewPerformKeyEquivalentOverride()

            var performKeyEquivalentEvents: [NSEvent] = []
            bmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView.window === window else { return nil }
                performKeyEquivalentEvents.append(event)
                return false
            }
            defer { bmuxUnitTestWKWebViewPerformKeyEquivalentHook = nil }

            let event = try #require(makeKeyDownEvent(
                key: "z",
                modifiers: [.command],
                keyCode: UInt16(kVK_ANSI_Z),
                windowNumber: window.windowNumber
            ))

            let handled = bmuxWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(handled)
            #expect(performKeyEquivalentEvents.isEmpty)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserUndoRedoDoesNotBypassMenuWhenWebInspectorResponderIsFocused() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            installBmuxUnitTestWKWebViewPerformKeyEquivalentOverride()

            let spy = BrowserUndoMenuActionSpy()
            let previousMenu = installUndoMenu(target: spy)
            defer { NSApp.mainMenu = previousMenu }

            let webView = try #require(window.contentView?.subviews.compactMap { $0 as? BmuxWebView }.first)
            let inspectorView = FakeWKInspectorUndoResponderView(frame: NSRect(x: 0, y: 0, width: 32, height: 20))
            webView.addSubview(inspectorView)

            var performKeyEquivalentEvents: [NSEvent] = []
            bmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView === webView else { return nil }
                performKeyEquivalentEvents.append(event)
                return true
            }
            defer { bmuxUnitTestWKWebViewPerformKeyEquivalentHook = nil }

            #expect(window.makeFirstResponder(inspectorView))
            let event = try #require(makeKeyDownEvent(
                key: "z",
                modifiers: [.command],
                keyCode: UInt16(kVK_ANSI_Z),
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(spy.invoked)
            #expect(performKeyEquivalentEvents.isEmpty)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @MainActor
    private func withHookedBrowserKeyDownWindow(
        _ body: (NSWindow, () -> [NSEvent]) throws -> Void
    ) rethrows {
        _ = NSApplication.shared
        AppDelegate.installWindowResponderSwizzlesForTesting()
        installBmuxUnitTestBmuxWebViewKeyDownOverride()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = container

        let webView = BmuxWebView(frame: container.bounds, configuration: WKWebViewConfiguration())
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        var keyDownEvents: [NSEvent] = []
        bmuxUnitTestBmuxWebViewKeyDownHook = { currentWebView, event in
            guard currentWebView === webView else { return false }
            keyDownEvents.append(event)
            return true
        }

        window.makeKeyAndOrderFront(nil)
        defer {
            bmuxUnitTestBmuxWebViewKeyDownHook = nil
            window.orderOut(nil)
        }

        #expect(window.makeFirstResponder(webView))
        try body(window, { keyDownEvents })
    }

    private func installUndoMenu(target: NSObject) -> NSMenu? {
        let previousMenu = NSApp.mainMenu
        let mainMenu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        let undoItem = NSMenuItem(
            title: "Undo",
            action: #selector(BrowserUndoMenuActionSpy.didInvoke(_:)),
            keyEquivalent: "z"
        )
        undoItem.keyEquivalentModifierMask = [.command]
        undoItem.target = target
        editMenu.addItem(undoItem)
        mainMenu.addItem(editItem)
        mainMenu.setSubmenu(editMenu, for: editItem)
        _ = NSApplication.shared
        NSApp.mainMenu = mainMenu
        return previousMenu
    }

    private func makeKeyDownEvent(
        key: String,
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16,
        windowNumber: Int
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
