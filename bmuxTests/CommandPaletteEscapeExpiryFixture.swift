import AppKit
import CoreFoundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the real main window and synchronous shortcut-state scope for expiry diagnostics.
@MainActor
final class CommandPaletteEscapeExpiryFixture {
    let app: AppDelegate
    private(set) var window: NSWindow?
    private var windowID: UUID?

    init(app: AppDelegate) { self.app = app }

    func dispatchEscape(observeDismiss: () -> Void) throws -> (consumed: Bool, entry: String, final: String) {
        try withDefaultShortcuts {
            AppDelegate.installWindowResponderSwizzlesForTesting()
            let previousFocusedWindow = debugShortcutRoutingFocusedWindowOverrideForTesting.window
            app.debugBeginShortcutRoutingFocusedWindowCaptureForTesting()
            KeyboardShortcutRecorderActivity.resetForTesting()
            defer {
                KeyboardShortcutRecorderActivity.resetForTesting()
                app.debugEndShortcutRoutingFocusedWindowCaptureForTesting()
                app.debugSetShortcutRoutingFocusedWindowForTesting(previousFocusedWindow)
            }
            let id = app.createMainWindow()
            windowID = id
            let window = try #require(NSApp.windows.first {
                $0.identifier?.rawValue == "bmux.main.\(id.uuidString)"
            })
            self.window = window
            window.isReleasedWhenClosed = false
            window.makeKey()
            #expect(app.debugSetCommandPalettePendingOpenAge(window: window, age: 20.0),
                    "Expected to seed an expired pending-open request state")
            app.setCommandPaletteVisible(false, for: window)
            observeDismiss()
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false, keyCode: 53
            ))
            let entry = state()
            let consumed = app.debugHandleCustomShortcut(event: event)
            return (consumed, entry, state())
        }
    }

    /// Reads only raw values; pending-open pruning and routing predicates are not diagnostic reads.
    func state() -> String {
        guard let windowID, let window else { return "ownedWindow=false" }
        let responder: String
        switch window.firstResponder {
        case nil: responder = "none"
        case is GhosttyNSView: responder = "terminal"
        case is NSTextView: responder = "textView"
        case is NSTextField: responder = "textField"
        default: responder = "other"
        }
        let pending = app.commandPaletteWindowStore.isPendingOpenRaw(windowID)
        let visible = app.commandPaletteWindowStore.isVisible(windowID)
        let captured = debugShortcutRoutingFocusedWindowOverrideForTesting.window === window
        return "pendingRaw=\(pending) visible=\(visible) keyOwned=\(NSApp.keyWindow === window) "
            + "mainOwned=\(NSApp.mainWindow === window) capturedOwned=\(captured) responder=\(responder) "
            + "recorder=\(KeyboardShortcutRecorderActivity.isAnyRecorderActive) "
            + "modal=\(NSApp.modalWindow != nil) sheet=\(window.attachedSheet != nil)"
    }

    func close() {
        guard let windowID, let window = window ?? NSApp.windows.first(where: {
            $0.identifier?.rawValue == "bmux.main.\(windowID.uuidString)"
        }) else { return }
        let prior = app.debugCloseMainWindowConfirmationHandler
        app.debugCloseMainWindowConfirmationHandler = { _ in true }
        defer { app.debugCloseMainWindowConfirmationHandler = prior }
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.orderOut(nil)
        window.close()
        self.window = nil
        self.windowID = nil
    }

    private func withDefaultShortcuts<T>(_ body: () throws -> T) throws -> T {
        let defaults = UserDefaults.standard
        let keys = KeyboardShortcutSettings.Action.allCases.map(\.defaultsKey) + [
            "bmux.settingsFile.backups.v1", "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
        ]
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let registration = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("escape-shortcuts-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            KeyboardShortcutSettings.settingsFileStore = originalStore
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            defaults.setVolatileDomain(registration, forName: UserDefaults.registrationDomain)
            KeyboardShortcutSettings.notifySettingsFileDidChange()
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned Escape shortcut settings") }
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        defaults.setVolatileDomain(registration.filter { !keys.contains($0.key) }, forName: UserDefaults.registrationDomain)
        let file = directory.appendingPathComponent("bmux.json")
        try "{}".write(to: file, atomically: true, encoding: .utf8)
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: file.path, fallbackPath: nil, additionalFallbackPaths: [], startWatching: false
        )
        return try body()
    }
}
