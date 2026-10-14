import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a real manual-I/O terminal and per-surface bindings without reading the clipboard.
@MainActor
final class GhosttyPasteShortcutFixture {
    let surface: TerminalSurface
    let window: NSWindow
    private let output: AsyncStream<Data>
    private let outputSignal: AsyncStream<Data>.Continuation
    private let readiness: TerminalRuntimeReadinessFixture
    private let timeout: Duration

    init(timeout: Duration) {
        self.timeout = timeout
        let (output, signal) = AsyncStream<Data>.makeStream()
        self.output = output
        outputSignal = signal
        surface = TerminalSurface(
            tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil, manualIO: true,
            manualInputHandler: { signal.yield($0) }
        )
        readiness = TerminalRuntimeReadinessFixture(surface: surface)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
    }

    func prepare() async throws -> GhosttyNSView {
        let content = try #require(window.contentView)
        let host = surface.hostedView
        host.frame = content.bounds
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if surface.surface == nil { try await readiness.wait(timeout: timeout) }
        _ = try #require(surface.surface)
        let scrollView = try #require(host.subviews.compactMap { $0 as? NSScrollView }.first)
        return try #require(scrollView.documentView?.subviews.first as? GhosttyNSView)
    }

    /// Every global probe is restored before returning to the asynchronous output wait.
    func dispatch(
        shift: Bool,
        view: GhosttyNSView,
        beforeDispatch: () -> Void
    ) throws -> (consumed: Bool, forwardedKeyPresses: Int) {
        let config = try #require(ghostty_config_new())
        defer { ghostty_config_free(config) }
        GhosttyApp.shared.loadInlineGhosttyConfig(
            "keybind = super+v=text:PLAIN_OVERRIDE\nkeybind = super+shift+v=text:SHIFT_OVERRIDE",
            into: config, prefix: "paste-shortcut-fixture", logLabel: "paste-shortcut-fixture"
        )
        ghostty_config_finalize(config)
        let runtime = try #require(surface.surface)
        ghostty_surface_update_config(runtime, config)

        let surface = surface
        let targetID = surface.id
        let configure: @MainActor @Sendable () -> Void = {
            if let runtime = surface.surface { ghostty_surface_update_config(runtime, config) }
        }
        // RuntimeLifecycle posts synchronously on MainActor before recreated input resumes.
        let observer = NotificationCenter.default.addObserver(
            forName: .terminalSurfaceDidBecomeReady, object: nil, queue: nil
        ) { notification in
            guard let target = notification.object as? TerminalSurface, target.id == targetID else { return }
            MainActor.assumeIsolated { configure() }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        AppDelegate.installWindowResponderSwizzlesForTesting()
        let previousMenu = NSApp.mainMenu
        let previousObserver = GhosttyNSView.debugGhosttySurfaceKeyEventObserver
        defer {
            NSApp.mainMenu = previousMenu
            GhosttyNSView.debugGhosttySurfaceKeyEventObserver = previousObserver
        }
        let menu = NSMenu(title: "Paste shortcut fixture")
        menu.addItem(withTitle: "Unrelated", action: nil, keyEquivalent: "n")
        NSApp.mainMenu = menu
        var forwardedKeyPresses = 0
        GhosttyNSView.debugGhosttySurfaceKeyEventObserver = { event in
            if event.action == GHOSTTY_ACTION_PRESS, event.keycode == 9 {
                forwardedKeyPresses += 1
            }
        }
        try #require(window.makeFirstResponder(view))
        beforeDispatch()
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero,
            modifierFlags: shift ? [.command, .shift] : [.command],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: shift ? "V" : "v", charactersIgnoringModifiers: "v",
            isARepeat: false, keyCode: 9
        ))
        let consumed = window.performKeyEquivalent(with: event)
        return (consumed, forwardedKeyPresses)
    }

    func nextOutput() async throws -> Data {
        let output = output
        let timeout = timeout
        return try await withThrowingTaskGroup(of: Data.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await data in output { return data }
                throw CancellationError()
            }
            group.addTask {
                // Injected failure deadline; cancellation joins the losing child, never settles UI.
                try await ContinuousClock().sleep(for: timeout)
                throw Failure.outputTimedOut
            }
            return try #require(await group.next())
        }
    }

    func close() {
        readiness.close()
        outputSignal.finish()
        surface.beginPortalCloseLifecycle(reason: "paste-shortcut-fixture.cleanup")
        surface.teardownSurface()
        window.contentView = nil
        window.close()
    }

    private enum Failure: Error { case outputTimedOut }
}
