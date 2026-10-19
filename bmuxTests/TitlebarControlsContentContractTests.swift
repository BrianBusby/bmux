import AppKit
import BmuxFoundation
import CoreFoundation
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct TitlebarControlsContentContractTests {
    @Test(arguments: [(0, 238.0), (1, 233.0)])
    func contentFitsRenderedControlsAndActionLanes(styleValue: Int, expectedWidth: Double) throws {
        let style = try #require(TitlebarControlsStyle(rawValue: styleValue))
        try withDefaultTitlebarSettings { defaults in
            let config = style.config
            let size = TitlebarControlsLayoutMetrics.contentSize(config: config)
            #expect(abs(size.width - expectedWidth) <= 0.001)
            #expect(abs(size.height - WindowChromeMetrics.appTitlebarHeight) <= 0.001)

            let button = NSHostingView(rootView: TitlebarControlButton(
                config: config, foregroundColor: .primary,
                accessibilityIdentifier: "fixture.button", accessibilityLabel: "Fixture", action: {}
            ) { Image(systemName: "bell") })
            let split = NSHostingView(rootView: TitlebarNewWorkspaceCloudSplitButton(
                config: config, foregroundColor: .primary, onNewTab: {}
            ).defaultAppStorage(defaults))
            #expect(button.fittingSize == NSSize(width: 28, height: 28))
            #expect(split.fittingSize == NSSize(width: 56, height: 28))

            let proxy = MinimalModeSidebarControlActionView(frame: NSRect(origin: .zero, size: size))
            proxy.config = config
            proxy.layoutSubtreeIfNeeded()
            var actions: [String] = []
            proxy.onAction = { slot, _, _ in actions.append(slot.accessibilityIdentifier) }
            let buttons = proxy.subviews.compactMap { $0 as? NSButton }
                .sorted { $0.frame.minX < $1.frame.minX }
            let expectedIDs = [
                "toggleSidebar", "showNotifications", "voiceInput", "newTab", "cloudVM",
                "focusHistoryBack", "focusHistoryForward",
            ].map { "titlebarControl." + $0 }
            #expect(buttons.map { $0.accessibilityIdentifier() } == expectedIDs)
            let leftMouseDown = try mouseEvent(.leftMouseDown)
            let rightMouseDown = try mouseEvent(.rightMouseDown)
            let keyDown = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: "a",
                charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
            ))
            let contextMenuIDs: Set<String> = [
                "titlebarControl.toggleSidebar", "titlebarControl.newTab", "titlebarControl.cloudVM",
                "titlebarControl.focusHistoryBack", "titlebarControl.focusHistoryForward",
            ]
            for button in buttons {
                #expect(button.frame.size == NSSize(width: 28, height: 28))
                #expect(proxy.bounds.contains(button.frame))
                for dx in [0.5, 27.5] {
                    let point = NSPoint(x: button.frame.minX + dx, y: proxy.bounds.midY)
                    #expect(proxy.performHitTest(at: point, currentEvent: leftMouseDown) === proxy)
                    #expect(proxy.performHitTest(at: point, currentEvent: nil) === proxy)
                    #expect(proxy.performHitTest(at: point, currentEvent: keyDown) == nil)
                    let acceptsContextMenu = contextMenuIDs.contains(button.accessibilityIdentifier())
                    #expect((proxy.performHitTest(at: point, currentEvent: rightMouseDown) === proxy) == acceptsContextMenu)
                }
                #expect(button.accessibilityPerformPress())
            }
            #expect(actions == expectedIDs)
            for (left, right) in zip(buttons, buttons.dropFirst()) where right.frame.minX > left.frame.maxX {
                let gap = NSPoint(x: (left.frame.maxX + right.frame.minX) / 2, y: proxy.bounds.midY)
                for event in [leftMouseDown, rightMouseDown, keyDown, nil] {
                    #expect(proxy.performHitTest(at: gap, currentEvent: event) == nil)
                }
            }
            let firstButton = try #require(buttons.first)
            let point = NSPoint(x: firstButton.frame.midX, y: proxy.bounds.midY)
            let outside = NSPoint(x: -1, y: proxy.bounds.midY)
            #expect(proxy.performHitTest(at: outside, currentEvent: leftMouseDown) == nil)
            proxy.isEnabled = false
            #expect(proxy.performHitTest(at: point, currentEvent: leftMouseDown) == nil)
            #expect(!firstButton.accessibilityPerformPress())
            proxy.isEnabled = true
            proxy.requiresRevealedState = true
            #expect(proxy.performHitTest(at: point, currentEvent: leftMouseDown) == nil)
            #expect(!firstButton.accessibilityPerformPress())
            #expect(actions == expectedIDs)
        }
    }

    private func mouseEvent(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        ))
    }

    private func withDefaultTitlebarSettings(_ body: (UserDefaults) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned titlebar fixture directory") }
        }
        let settingsURL = root.appendingPathComponent("bmux.json")
        try Data("{}".utf8).write(to: settingsURL)
        let suiteName = "titlebar-content-\(UUID().uuidString)"
        let isolatedDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }
        let actions = TitlebarShortcutHintActionSlot.allCases.compactMap(\.action)
        let keys = actions.map(\.defaultsKey) + [
            GlobalFontMagnification.percentKey,
            "bmux.settingsFile.backups.v1",
            "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
            SystemWideHotkeySettings.legacyShortcutKey,
        ]
        let defaults = UserDefaults.standard
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let domains = [UserDefaults.argumentDomain, UserDefaults.registrationDomain]
        let savedDomains = domains.map { defaults.volatileDomain(forName: $0) }
        // The legacy owner reads process-wide settings. Never suspend while this
        // scope is installed; restore persistent and fallback domains separately.
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            for (name, values) in zip(domains, savedDomains) {
                defaults.setVolatileDomain(values, forName: name)
            }
            KeyboardShortcutSettings.settingsFileStore = originalStore
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsURL.path, fallbackPath: nil, additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(), startWatching: false
        )
        for action in actions {
            defaults.set(try JSONEncoder().encode(action.defaultShortcut), forKey: action.defaultsKey)
        }
        defaults.set(GlobalFontMagnification.defaultPercent, forKey: GlobalFontMagnification.percentKey)
        try body(isolatedDefaults)
    }
}
