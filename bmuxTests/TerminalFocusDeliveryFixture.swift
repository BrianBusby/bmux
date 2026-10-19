import Foundation
import BmuxTerminal

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Buffers the actual terminal first-responder notification before a focus action.
@MainActor
final class TerminalFocusDeliveryFixture {
    private let events: AsyncStream<Void>
    private let signal: AsyncStream<Void>.Continuation
    private var observer: NSObjectProtocol?

    init(surface: TerminalSurface) {
        let surfaceID = surface.id
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.events = events
        self.signal = signal
        observer = NotificationCenter.default.addObserver(
            forName: .ghosttyDidBecomeFirstResponderSurface, object: nil, queue: nil
        ) { notification in
            if notification.userInfo?[GhosttyNotificationKey.surfaceId] as? UUID == surfaceID {
                signal.yield(())
            }
        }
    }

    func wait(timeout: Duration) async throws {
        let events = events
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // The injected failure deadline replaces polling, never delays successful focus.
                try await clock.sleep(until: deadline)
                throw Failure.focusDeliveryTimedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    func close() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        signal.finish()
    }

    private enum Failure: Error { case focusDeliveryTimedOut }
}
