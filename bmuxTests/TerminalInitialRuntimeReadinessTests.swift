import AppKit
import BmuxTerminal
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct TerminalInitialRuntimeReadinessTests {
    @Test(arguments: [false, true])
    func initialInputOrCommandCreatesRuntimeWithoutAUserWindow(command: Bool) async throws {
        let workspaceID = UUID()
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let observer = NotificationCenter.default.addObserver(
            forName: .terminalSurfaceDidBecomeReady, object: nil, queue: nil
        ) { notification in
            if let surface = notification.object as? TerminalSurface, surface.tabId == workspaceID {
                signal.yield(())
            }
        }
        defer { NotificationCenter.default.removeObserver(observer); signal.finish() }
        let panel = command
            ? TerminalPanel(workspaceId: workspaceID, initialCommand: "echo startup")
            : TerminalPanel(workspaceId: workspaceID, initialInput: "echo resume\n")
        defer { panel.surface.teardownSurface() }
        #expect(panel.surface.debugHasHeadlessStartupWindowForTesting(), "Initial work bootstraps through a hidden window")
        #expect(panel.surface.uiWindow == nil)
        if panel.surface.surface == nil { try await waitForReady(events, timeout: .seconds(3)) }
        #expect(panel.surface.surface != nil)
        #expect(panel.surface.debugRuntimeSurfaceCreateAttemptCountForTesting() > 0,
                "Initial work must create the runtime without a user window attachment")
        #expect(panel.surface.debugHasHeadlessStartupWindowForTesting())
        #expect(panel.surface.uiWindow == nil)
    }

    @Test
    func plainHostedViewWindowAttachmentCreatesRuntimeSurface() async throws {
        let panel = TerminalPanel(workspaceId: UUID())
        #expect(panel.hostedView.debugSurfaceId == panel.surface.id)
        #expect(panel.surface.surface == nil)
        #expect(!panel.surface.debugHasHeadlessStartupWindowForTesting())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            panel.hostedView.removeFromSuperview()
            panel.surface.teardownSurface()
            window.contentView = nil
            window.close()
        }
        let content = try #require(window.contentView)
        let readiness = TerminalRuntimeReadinessFixture(surface: panel.surface)
        defer { readiness.close() }
        panel.hostedView.frame = content.bounds
        panel.hostedView.autoresizingMask = [.width, .height]
        content.addSubview(panel.hostedView)
        content.layoutSubtreeIfNeeded()
        panel.hostedView.layoutSubtreeIfNeeded()
        if panel.surface.surface == nil { try await readiness.wait(timeout: .seconds(3)) }
        #expect(panel.surface.surface != nil,
                "Direct AppKit attachment must create the runtime without input demand")
        #expect(panel.surface.debugRuntimeSurfaceCreateAttemptCountForTesting() > 0)
        #expect(!panel.surface.debugHasHeadlessStartupWindowForTesting())
    }

    private func waitForReady(_ events: AsyncStream<Void>, timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Genuine async readiness failure bound, injected rather than a settling delay.
                try await ContinuousClock().sleep(for: timeout)
                throw Failure.runtimeReadinessTimedOut
            }
            _ = try await group.next()
        }
    }

    private enum Failure: Error { case runtimeReadinessTimedOut }
}
