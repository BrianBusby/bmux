import AppKit
import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
extension BrowserDeveloperToolsVisibilityPersistenceTests {
    func makePanelWithInspector(
        hideBehavior: FakeInspector.HideBehavior = .unsupported
    ) -> (BrowserPanel, FakeInspector) {
        let panel = BrowserPanel(workspaceId: UUID())
        let inspector = FakeInspector(hideBehavior: hideBehavior)
        panel.webView.bmuxSetUnitTestInspector(inspector)
        return (panel, inspector)
    }

    func withTemporaryShortcut(
        action: KeyboardShortcutSettings.Action,
        shortcut: BrowserConfigStoredShortcut,
        _ body: () -> Void
    ) {
        let hadPersistedShortcut = UserDefaults.standard.object(forKey: action.defaultsKey) != nil
        let originalShortcut = KeyboardShortcutSettings.shortcut(for: action)
        defer {
            if hadPersistedShortcut {
                KeyboardShortcutSettings.setShortcut(originalShortcut, for: action)
            } else {
                KeyboardShortcutSettings.resetShortcut(for: action)
            }
#if DEBUG
            AppDelegate.shared?.debugResetShortcutRoutingStateForTesting(clearFocusedWindowOverride: false)
#endif
        }
        KeyboardShortcutSettings.setShortcut(shortcut, for: action)
#if DEBUG
        AppDelegate.shared?.debugResetShortcutRoutingStateForTesting(clearFocusedWindowOverride: false)
#endif
        body()
    }

    func spinRunLoopOneTick() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    func waitForBrowserCondition(
        timeout: TimeInterval = 1.0,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    func waitForKeyWindow(_ window: NSWindow, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if window.isKeyWindow || AppDelegate.shared?.shortcutRoutingKeyWindow === window { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTFail("Timed out waiting for key window", file: file, line: line)
    }

    func installShortcutRoutingKeyWindowOverride(_ window: NSWindow) -> () -> Void {
#if DEBUG
        guard let appDelegate = AppDelegate.shared else { return {} }
        appDelegate.debugBeginShortcutRoutingFocusedWindowCaptureForTesting()
        appDelegate.debugSetShortcutRoutingFocusedWindowForTesting(window)
        return { appDelegate.debugEndShortcutRoutingFocusedWindowCaptureForTesting() }
#else
        return {}
#endif
    }

    func window(withId windowId: UUID) -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == "bmux.main.\(windowId.uuidString)" }
    }

    func findHostContainerView(in root: NSView) -> WebViewRepresentable.HostContainerView? {
        if let host = root as? WebViewRepresentable.HostContainerView { return host }
        for subview in root.subviews {
            if let host = findHostContainerView(in: subview) { return host }
        }
        return nil
    }

    func waitForDetachedDeveloperToolsCloseResolutionDeadline(
        until condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(2.0 + 0.35 + 0.5)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTFail("Timed out waiting for detached DevTools close resolution", file: file, line: line)
    }

    func waitForDeveloperToolsTransitions(
        panel: BrowserPanel,
        until condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitForDetachedDeveloperToolsCloseResolutionDeadline(
            until: {
                let summary = panel.debugDeveloperToolsStateSummary()
                return summary.contains("tx=nil") &&
                    summary.contains("pending=nil") &&
                    summary.contains("closeResolution=0") &&
                    condition()
            },
            file: file,
            line: line
        )
    }

    var commandWCloseTabShortcut: BrowserConfigStoredShortcut {
        BrowserConfigStoredShortcut(key: "w", command: true, shift: false, option: false, control: false, keyCode: 13)
    }

    func closeBrowserPanel(_ panel: BrowserPanel) {
        panel.close()
        BrowserWindowPortalRegistry.detach(webView: panel.webView)
        panel.webView.bmuxSetUnitTestInspector(nil)
        panel.webView.removeFromSuperview()
    }

    func closeWindow(_ window: NSWindow) {
        window.contentView = nil
        window.orderOut(nil)
        window.close()
    }

    func tearDownMainWindow(_ window: NSWindow, manager: TabManager) {
        let browserPanels = manager.tabs.flatMap { workspace in
            workspace.panels.values.compactMap { $0 as? BrowserPanel }
        }
        for workspace in manager.tabs {
            workspace.teardownAllPanels()
        }
        for browserPanel in browserPanels {
            BrowserWindowPortalRegistry.detach(webView: browserPanel.webView)
            browserPanel.webView.bmuxSetUnitTestInspector(nil)
            browserPanel.webView.removeFromSuperview()
        }
        closeWindow(window)
        spinRunLoopOneTick()
    }
}
