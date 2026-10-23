import AppKit
import SwiftUI
import WebKit
import Bonsplit
import Testing
@testable import bmux_DEV

@MainActor
extension BrowserInspectorWindowOwnershipTests {
    @Test
    func detachedInspectorChordedCloseTabClosesInspectorWithoutClosingBrowserPanel() async throws {

        let chordedCloseTab = BrowserConfigStoredShortcut(
            key: "b",
            command: false,
            shift: false,
            option: false,
            control: true,
            keyCode: 11,
            chordKey: "n",
            chordCommand: false,
            chordShift: false,
            chordOption: false,
            chordControl: false,
            chordKeyCode: 45
        )

        let main = try BrowserInspectorMainWindowFixture()
        defer { main.close() }
        let workspace = main.workspace
        let browserPanelId = main.panelID
        let fixture = main.inspectorFixture
        let browserPanel = fixture.panel
        let inspector = fixture.inspector
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Web Inspector — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }

        var routingSnapshots: [String] = []
        let recordRouting: @MainActor (String) -> Void = { phase in
            routingSnapshots.append("phase=\(phase) active=\(NSApp.isActive) " +
                "nativeKey=\(inspectorWindow.isKeyWindow) " +
                "routingMatches=\(AppDelegate.shared?.shortcutRoutingKeyWindow === inspectorWindow) " +
                "visible=\(inspectorWindow.isVisible) preferred=\(browserPanel.preferredDeveloperToolsVisible)")
        }
        let observation = browserPanel.debugDeveloperToolsLifecycleChanges()
        defer { browserPanel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        try main.withRoutingWindow(inspectorWindow) {
            inspectorWindow.makeKeyAndOrderFront(nil)
            inspectorWindow.makeKey()
            #expect(browserPanel.showDeveloperTools())
            #expect(inspector.closeCount == 0)

            let prefixEvent = try #require(NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.control],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: inspectorWindow.windowNumber,
                context: nil,
                characters: "b",
                charactersIgnoringModifiers: "b",
                isARepeat: false,
                keyCode: 11
            ))
            let suffixEvent = try #require(NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: inspectorWindow.windowNumber,
                context: nil,
                characters: "n",
                charactersIgnoringModifiers: "n",
                isARepeat: false,
                keyCode: 45
            ))

            try main.withTemporaryShortcut(chordedCloseTab) {
                let appDelegate = try #require(AppDelegate.shared)
                recordRouting("before_prefix")
                #expect(appDelegate.handleConfiguredShortcutKeyEquivalent(prefixEvent))
                recordRouting("after_prefix")

                #expect(inspectorWindow.isVisible)
                #expect(workspace.browserPanel(for: browserPanelId) != nil, "Close Tab chord prefix must not close the browser panel")

                #expect(appDelegate.handleConfiguredShortcutKeyEquivalent(suffixEvent))
                recordRouting("after_suffix")

            }
        }
        try await fixture.waitForTransitions(observation: observation) {
            !inspectorWindow.isVisible &&
                browserPanel.debugDeveloperToolsStateSummary().contains("pref=0")
        }

        #expect(inspector.closeCount == 0, "Chorded Close Tab in a detached Web Inspector must not call _inspector.close on the inspected page")
        #expect(!(inspectorWindow.isVisible), "inspector_chord_close_failed \(routingSnapshots.joined(separator: ";"))")
        #expect(workspace.browserPanel(for: browserPanelId) != nil, "Chorded Close Tab in a detached Web Inspector must not fall through to bmux close-tab routing")
        #expect(browserPanel.debugDeveloperToolsStateSummary().contains("pref=0"),
            "inspector_chord_preference_failed \(routingSnapshots.joined(separator: ";"))")
    }

    @Test
    func detachedInspectorCloseButtonActionClosesWindowWithoutReenteringInspectorClose() async throws {
        let main = try BrowserInspectorMainWindowFixture()
        defer { main.close() }
        let fixture = main.inspectorFixture
        let browserPanel = fixture.panel
        let inspector = fixture.inspector
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Web Inspector — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }
        let observation = browserPanel.debugDeveloperToolsLifecycleChanges()
        defer { browserPanel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        main.withRoutingWindow(inspectorWindow) {
            inspectorWindow.makeKeyAndOrderFront(nil)
            inspectorWindow.makeKey()
            #expect(browserPanel.showDeveloperTools())
            #expect(browserPanel.isDeveloperToolsVisible())
            #expect(inspector.closeCount == 0)
            var willCloseNotificationCount = 0
            let observer = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: inspectorWindow,
                queue: nil
            ) { _ in
                // queue:nil delivers synchronously from this MainActor close action.
                MainActor.assumeIsolated { willCloseNotificationCount += 1 }
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            let handled = NSApp.sendAction(
                NSSelectorFromString("__close"),
                to: inspectorWindow,
                from: inspectorWindow.standardWindowButton(.closeButton)
            )

            #expect(handled)
            #expect(inspector.closeCount == 0, "The close-button action must close the inspector window without calling _inspector.close on the inspected page")
            #expect(willCloseNotificationCount == 1, "The intercepted close-button action should close the WebKit-owned inspector window exactly once")
            #expect(!(inspectorWindow.isVisible))
        }
        try await fixture.waitForTransitions(observation: observation) {
            !inspectorWindow.isVisible &&
                browserPanel.debugDeveloperToolsStateSummary().contains("pref=0")
        }
        #expect(!(inspectorWindow.isVisible))
        #expect(browserPanel.debugDeveloperToolsStateSummary().contains("pref=0"))
    }

    @Test
    func detachedInspectorNilTargetCloseActionUsesKeyWindow() async throws {
        let main = try BrowserInspectorMainWindowFixture()
        defer { main.close() }
        let fixture = main.inspectorFixture
        let browserPanel = fixture.panel
        let inspector = fixture.inspector
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Web Inspector — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }
        let observation = browserPanel.debugDeveloperToolsLifecycleChanges()
        defer { browserPanel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        main.withRoutingWindow(inspectorWindow) {
            inspectorWindow.makeKeyAndOrderFront(nil)
            inspectorWindow.makeKey()
            #expect(browserPanel.showDeveloperTools())
            #expect(inspector.closeCount == 0)
            let handled = NSApp.sendAction(NSSelectorFromString("__close"), to: nil, from: nil)

            #expect(handled)
            #expect(inspector.closeCount == 0, "Menu and keyboard close actions without an explicit target must close the inspector window without reentering _inspector.close")
            #expect(!(inspectorWindow.isVisible))
            #expect(browserPanel.debugDeveloperToolsStateSummary().contains("pref=0"))
        }
    }

    @Test
    func detachedInspectorNilTargetMenuItemCloseActionUsesKeyWindow() async throws {
        let main = try BrowserInspectorMainWindowFixture()
        defer { main.close() }
        let fixture = main.inspectorFixture
        let browserPanel = fixture.panel
        let inspector = fixture.inspector
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Inspector Localized — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }
        let observation = browserPanel.debugDeveloperToolsLifecycleChanges()
        defer { browserPanel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        main.withRoutingWindow(inspectorWindow) {
            inspectorWindow.makeKeyAndOrderFront(nil)
            inspectorWindow.makeKey()
            #expect(browserPanel.showDeveloperTools())
            #expect(inspector.closeCount == 0)
            let menuItem = NSMenuItem(
                title: "Close",
                action: NSSelectorFromString("close:"),
                keyEquivalent: "w"
            )
            let handled = NSApp.sendAction(NSSelectorFromString("close:"), to: nil, from: menuItem)

            #expect(handled)
            #expect(inspector.closeCount == 0, "Nil-target menu Close actions must resolve and close the key detached inspector window without reentering _inspector.close")
            #expect(!(inspectorWindow.isVisible))
            #expect(browserPanel.debugDeveloperToolsStateSummary().contains("pref=0"))
        }
    }

    @Test
    func detachedInspectorCommandWClosesInspectorWithoutClosingBrowserPanel() async throws {
        let main = try BrowserInspectorMainWindowFixture()
        defer { main.close() }
        let workspace = main.workspace
        let browserPanelId = main.panelID
        let fixture = main.inspectorFixture
        let browserPanel = fixture.panel
        let inspector = fixture.inspector
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Web Inspector — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }
        let observation = browserPanel.debugDeveloperToolsLifecycleChanges()
        defer { browserPanel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        try main.withRoutingWindow(inspectorWindow) {
            inspectorWindow.makeKeyAndOrderFront(nil)
            inspectorWindow.makeKey()
            #expect(browserPanel.showDeveloperTools())
            #expect(inspector.closeCount == 0)
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: inspectorWindow.windowNumber,
                context: nil,
                characters: "w",
                charactersIgnoringModifiers: "w",
                isARepeat: false,
                keyCode: 13
            ))
            try main.withTemporaryShortcut(BrowserConfigStoredShortcut(key: "w", command: true, shift: false, option: false, control: false, keyCode: 13)) {
                NSApp.sendEvent(event)

            }
        }
        try await fixture.waitForTransitions(observation: observation) {
            !inspectorWindow.isVisible &&
                browserPanel.debugDeveloperToolsStateSummary().contains("pref=0")
        }
        #expect(inspector.closeCount == 0, "Cmd-W in a detached Web Inspector must not call _inspector.close on the inspected page")
        #expect(!(inspectorWindow.isVisible))
        #expect(workspace.browserPanel(for: browserPanelId) != nil, "Cmd-W in a detached Web Inspector must not fall through to bmux close-tab routing")
        #expect(browserPanel.debugDeveloperToolsStateSummary().contains("pref=0"))
    }

    @Test
    func detachedInspectorCommandWIgnoresStaleMainEventWindow() async throws {
        let main = try BrowserInspectorMainWindowFixture()
        defer { main.close() }
        let mainWindow = main.window
        let workspace = main.workspace
        let browserPanelId = main.panelID
        let fixture = main.inspectorFixture
        let browserPanel = fixture.panel
        let inspector = fixture.inspector
        let inspectorWindow = fixture.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240))
        inspectorWindow.title = "Inspector Localized — example.com"
        let frontendWebView = WKInspectorProbeWebView(
            frame: inspectorWindow.contentView?.bounds ?? .zero,
            configuration: WKWebViewConfiguration()
        )
        inspectorWindow.contentView?.addSubview(frontendWebView)
        inspector.setFrontendWebView(frontendWebView)
        defer { fixture.closeWindow(inspectorWindow) }
        let observation = browserPanel.debugDeveloperToolsLifecycleChanges()
        defer { browserPanel.debugRemoveDeveloperToolsLifecycleObserver(observation.id) }
        try main.withRoutingWindow(inspectorWindow) {
            inspectorWindow.makeKeyAndOrderFront(nil)
            inspectorWindow.makeKey()
            #expect(browserPanel.showDeveloperTools())
            #expect(inspector.closeCount == 0)
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: mainWindow.windowNumber,
                context: nil,
                characters: "w",
                charactersIgnoringModifiers: "w",
                isARepeat: false,
                keyCode: 13
            ))
            try main.withTemporaryShortcut(BrowserConfigStoredShortcut(key: "w", command: true, shift: false, option: false, control: false, keyCode: 13)) {
                NSApp.sendEvent(event)

            }
        }
        try await fixture.waitForTransitions(observation: observation) {
            !inspectorWindow.isVisible &&
                browserPanel.debugDeveloperToolsStateSummary().contains("pref=0")
        }
        #expect(inspector.closeCount == 0, "Cmd-W with stale main-window event metadata must not call _inspector.close on the inspected page")
        #expect(!(inspectorWindow.isVisible))
        #expect(workspace.browserPanel(for: browserPanelId) != nil, "Cmd-W with stale main-window event metadata must not fall through to bmux close-tab routing")
        #expect(browserPanel.debugDeveloperToolsStateSummary().contains("pref=0"))
    }
}
