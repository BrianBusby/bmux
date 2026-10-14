import Foundation
import BmuxTerminal

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Subscribes before a runtime-creating action and owns its bounded, cancellable wait.
@MainActor
final class TerminalRuntimeReadinessFixture {
    private let events: AsyncStream<Void>
    private let signal: AsyncStream<Void>.Continuation
    private var observer: NSObjectProtocol?

    init(surface: TerminalSurface) {
        let surfaceID = surface.id
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.events = events
        self.signal = signal
        observer = NotificationCenter.default.addObserver(
            forName: .terminalSurfaceDidBecomeReady, object: nil, queue: nil
        ) { notification in
            if let candidate = notification.object as? TerminalSurface, candidate.id == surfaceID {
                signal.yield(())
            }
        }
    }

    func wait(timeout: Duration) async throws {
        let events = events
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // A failure deadline, never a settling delay; cancellation joins both children.
                try await ContinuousClock().sleep(for: timeout)
                throw Failure.runtimeReadinessTimedOut
            }
            _ = try await group.next()
        }
    }

    func close() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        signal.finish()
    }

    private enum Failure: Error { case runtimeReadinessTimedOut }
}
