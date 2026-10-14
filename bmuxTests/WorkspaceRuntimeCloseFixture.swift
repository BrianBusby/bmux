import AppKit
import BmuxTerminal
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a real terminal runtime and subscribes before attaching its retained window.
@MainActor
final class WorkspaceRuntimeCloseFixture {
    let manager = TabManager()
    let workspace: Workspace
    let panel: TerminalPanel
    private let window: NSWindow

    init() throws {
        workspace = manager.addWorkspace()
        manager.selectWorkspace(workspace)
        let panelID = try #require(workspace.focusedPanelId)
        panel = try #require(workspace.terminalPanel(for: panelID))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
    }

    func prepareRuntime(timeout: Duration = .seconds(3)) async throws {
        let surfaceID = panel.surface.id
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let observer = NotificationCenter.default.addObserver(
            forName: .terminalSurfaceDidBecomeReady, object: nil, queue: nil
        ) { notification in
            guard let surface = notification.object as? TerminalSurface else { return }
            if surface.id == surfaceID { signal.yield(()) }
        }
        defer { NotificationCenter.default.removeObserver(observer); signal.finish() }
        let content = try #require(window.contentView)
        let host = panel.surface.hostedView
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        if panel.surface.surface == nil {
            try await withThrowingTaskGroup(of: Void.self) { group in
                defer { group.cancelAll() }
                group.addTask {
                    for await _ in events { return }
                    throw CancellationError()
                }
                group.addTask {
                    // Original failure bound; readiness comes from the native lifecycle event.
                    try await ContinuousClock().sleep(for: timeout)
                    throw Failure.runtimeReadinessTimedOut
                }
                _ = try await group.next()
            }
        }
        try #require(panel.surface.surface != nil, "Workspace close must exercise a real ready runtime")
    }

    func close() {
        workspace.teardownAllPanels()
        for owned in manager.tabs { owned.teardownAllPanels() }
        window.contentView = nil
        window.close()
    }

    private enum Failure: Error { case runtimeReadinessTimedOut }
}
