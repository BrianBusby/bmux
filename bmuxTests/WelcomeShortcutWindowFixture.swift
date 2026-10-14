import AppKit
import CoreFoundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the registered Welcome window and the legacy shortcut event-delivery boundary.
@MainActor
final class WelcomeShortcutWindowFixture {
    private let appDelegate: AppDelegate
    private let window: NSWindow
    private let manager: TabManager
    private let sidebar = SidebarState(isVisible: true)
    private let explorer: FileExplorerState
    private var priorVisibility: CFPropertyList?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        let keys = ["fileExplorer.isVisible", "rightSidebar.mode"]
        let saved = keys.map(Self.persistedValue)
        defer { Self.restore(keys: keys, values: saved) }
        explorer = FileExplorerState()
        explorer.setVisible(false)
        manager = TabManager()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        // Swift retains this window through performClose and subsequent autorelease drains.
        window.isReleasedWhenClosed = false
        let windowID = UUID()
        window.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(windowID.uuidString)")
        appDelegate.registerMainWindow(
            window,
            windowId: windowID,
            tabManager: manager,
            sidebarState: sidebar,
            sidebarSelectionState: SidebarSelectionState(),
            fileExplorerState: explorer
        )
    }

    func close() {
        for workspace in manager.tabs { workspace.teardownAllPanels() }
        window.performClose(nil)
        window.contentView = nil
        window.orderOut(nil)
    }

    /// Settings and focus overrides are restored synchronously before the caller suspends.
    func routeShortcuts(assertHandled: (Bool, Bool, Bool) -> Void) throws -> AsyncStream<Bool> {
        try withDefaultShortcuts {
            AppDelegate.installWindowResponderSwizzlesForTesting()
            let priorFocusedWindow = debugShortcutRoutingFocusedWindowOverrideForTesting.window
            appDelegate.debugBeginShortcutRoutingFocusedWindowCaptureForTesting()
            defer {
                appDelegate.debugEndShortcutRoutingFocusedWindowCaptureForTesting()
                appDelegate.debugSetShortcutRoutingFocusedWindowForTesting(priorFocusedWindow)
            }
            window.makeKeyAndOrderFront(nil)
            let left = try event(modifiers: [.command])
            let right = try event(modifiers: [.command, .option])
            let leftHandled = appDelegate.debugHandleCustomShortcut(event: left)
            let leftVisible = sidebar.isVisible
            let completion = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
            // The real handler enqueues exactly one main-queue toggle. Bracket that
            // event in FIFO delivery, preserving the defaults value at execution time.
            DispatchQueue.main.async {
                self.priorVisibility = Self.persistedValue("fileExplorer.isVisible")
            }
            let rightHandled = appDelegate.debugHandleCustomShortcut(event: right)
            DispatchQueue.main.async { [self] in
                MainActor.assumeIsolated {
                    let visible = explorer.isVisible
                    Self.restore(keys: ["fileExplorer.isVisible"], values: [self.priorVisibility])
                    completion.continuation.yield(visible)
                    completion.continuation.finish()
                }
            }
            assertHandled(leftHandled, leftVisible, rightHandled)
            return completion.stream
        }
    }

    func awaitRightSidebarToggle(_ events: AsyncStream<Bool>, timeout: Duration = .seconds(1)) async throws -> Bool {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await visible in events { return visible }
                throw CancellationError()
            }
            group.addTask {
                // Original one-second failure deadline; never a settling or polling delay.
                try await ContinuousClock().sleep(for: timeout)
                throw FixtureFailure.rightSidebarDeliveryTimedOut
            }
            return try await group.next() ?? false
        }
    }

    private func event(modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "b", charactersIgnoringModifiers: "b", isARepeat: false, keyCode: 11
        ))
    }

    private func withDefaultShortcuts<T>(_ body: () throws -> T) throws -> T {
        let defaults = UserDefaults.standard
        let keys = KeyboardShortcutSettings.Action.allCases.map(\.defaultsKey) + [
            "bmux.settingsFile.backups.v1", "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
        ]
        let saved = keys.map(Self.persistedValue)
        let registration = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("welcome-shortcuts-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            KeyboardShortcutSettings.settingsFileStore = originalStore
            Self.restore(keys: keys, values: saved)
            defaults.setVolatileDomain(registration, forName: UserDefaults.registrationDomain)
            KeyboardShortcutSettings.notifySettingsFileDidChange()
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned Welcome shortcut settings") }
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

    private static func persistedValue(_ key: String) -> CFPropertyList? {
        CFPreferencesCopyValue(key as CFString, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func restore(keys: [String], values: [CFPropertyList?]) {
        for (key, value) in zip(keys, values) {
            if let value { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }

    private enum FixtureFailure: Error { case rightSidebarDeliveryTimedOut }
}
