import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

/// Owns the terminal and synchronous composition used by real terminal input dismissal.
@MainActor
final class NotificationInteractionFixture {
    enum Input { case keyDown, mouseDown }

    private let manager = TabManager()
    private let window: NSWindow

    init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
    }

    func prepare() async throws {
        let panel = try #require(manager.selectedWorkspace?.focusedTerminalPanel)
        let content = try #require(window.contentView)
        let readiness = TerminalRuntimeReadinessFixture(surface: panel.surface)
        defer { readiness.close() }
        panel.hostedView.frame = content.bounds
        panel.hostedView.autoresizingMask = [.width, .height]
        content.addSubview(panel.hostedView)
        content.layoutSubtreeIfNeeded()
        panel.hostedView.layoutSubtreeIfNeeded()
        if panel.surface.surface == nil { try await readiness.wait(timeout: .seconds(3)) }
        try #require(panel.surface.surface != nil, "Runtime must exist before testing input dismissal")
    }

    func close() {
        for workspace in manager.tabs {
            TerminalNotificationStore.shared.clearNotifications(forTabId: workspace.id)
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
        }
        window.contentView = nil
        window.close()
    }

    /// Restores all composition and preference overrides before returning its queued result.
    func interact(_ input: Input, assertState: (Bool, Bool, Bool) -> Void) throws -> AsyncStream<Int> {
        FocusSurfaceBroadcaster.shared.flush()
        let previousDelegate = AppDelegate.shared
        let app = previousDelegate ?? AppDelegate()
        let previousManager = app.tabManager
        let previousStore = app.notificationStore
        let previousFocus = AppFocusState.overrideIsFocused
        let store = TerminalNotificationStore.shared
        let defaults = UserDefaults.standard
        let keys = [NotificationPaneFlashSettings.enabledKey, TmuxOverlayExperimentSettings.enabledKey,
                    TmuxOverlayExperimentSettings.targetKey]
        let values = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        app.tabManager = manager
        app.notificationStore = store
        AppFocusState.overrideIsFocused = true
        defaults.set(true, forKey: keys[0])
        defaults.set(true, forKey: keys[1])
        defaults.set(TmuxOverlayExperimentTarget.surface.rawValue, forKey: keys[2])
        defer {
            for workspace in manager.tabs { store.clearNotifications(forTabId: workspace.id) }
            FocusSurfaceBroadcaster.shared.flush()
            app.tabManager = previousManager
            app.notificationStore = previousStore
            AppDelegate.shared = previousDelegate
            AppFocusState.overrideIsFocused = previousFocus
            for (key, value) in zip(keys, values) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        let workspace = try #require(manager.selectedWorkspace)
        let panel = try #require(workspace.focusedTerminalPanel)
        let view = try #require(panel.hostedView.subviews.compactMap { $0 as? NSScrollView }.first?
            .documentView?.subviews.first as? GhosttyNSView)
        let becameFirstResponder = window.makeFirstResponder(view)
        // Finish setup focus delivery before seeding the unread record for the input action.
        FocusSurfaceBroadcaster.shared.flush()
        store.restoreSessionNotifications([
            TerminalNotification(id: UUID(), tabId: workspace.id, surfaceId: panel.id,
                title: "Unread", subtitle: "", body: "", createdAt: Date(), isRead: false)
        ], forTabId: workspace.id)
        let unreadBefore = store.hasUnreadNotification(forTabId: workspace.id, surfaceId: panel.id)
        let panelID = panel.id
        let before = GhosttySurfaceScrollView.flashCount(for: panelID)
        switch input {
        case .keyDown:
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 122))
            view.keyDown(with: event)
        case .mouseDown:
            let point = view.convert(NSPoint(x: 20, y: 20), to: nil)
            let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1))
            view.mouseDown(with: event)
        }
        assertState(becameFirstResponder, unreadBefore,
                    store.hasUnreadNotification(forTabId: workspace.id, surfaceId: panel.id))
        let delivery = AsyncStream<Int>.makeStream(bufferingPolicy: .bufferingNewest(1))
        // triggerFlash queues exactly one renderer callback. As in WelcomeShortcutWindowFixture,
        // this FIFO boundary observes that event; it is not a wall-clock settling delay.
        DispatchQueue.main.async {
            delivery.continuation.yield(GhosttySurfaceScrollView.flashCount(for: panelID) - before)
            delivery.continuation.finish()
        }
        return delivery.stream
    }

    func awaitFlash(_ events: AsyncStream<Int>, timeout: Duration = .seconds(1)) async throws -> Int {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let count = try await withThrowingTaskGroup(of: Int.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await count in events { return count }
                throw CancellationError()
            }
            group.addTask {
                // The original one-second queue-drain failure bound, not a settling delay.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.rendererDeliveryTimedOut
            }
            return try await group.next() ?? 0
        }
        try Task.checkCancellation()
        return count
    }

    private enum Failure: Error { case rendererDeliveryTimedOut }
}
