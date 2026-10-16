import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct CommandPaletteEscapeExpiryTests {
    @Test
    func escapeDoesNotConsumeWhenMenuTriggeredPendingOpenStateExpires() async throws {
        try await withinAllowance(.seconds(30)) {
            let fixture = CommandPaletteEscapeExpiryFixture(app: try #require(AppDelegate.shared))
            defer { fixture.close() }
            let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            var observer: NSObjectProtocol?
            defer {
                if let observer { NotificationCenter.default.removeObserver(observer) }
                signal.finish()
            }
            let result = try fixture.dispatchEscape {
                observer = NotificationCenter.default.addObserver(
                    forName: .commandPaletteDismissRequested, object: nil, queue: nil
                ) { _ in signal.yield(()) }
            }
            #expect(!result.consumed,
                    "Escape should pass through once pending-open grace has expired; entry: \(result.entry); final: \(result.final)")
            let dismissed = try await observedDismiss(events, during: .milliseconds(200))
            #expect(!dismissed,
                    "No dismiss notification for expired pending-open state; entry: \(result.entry); final: \(fixture.state())")
        }
    }

    private func observedDismiss(_ events: AsyncStream<Void>, during duration: Duration) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: duration)
        let dismissed = try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return true }
                throw CancellationError()
            }
            group.addTask {
                // Original 0.2-second inverted-notification observation window, not UI settling.
                try await ContinuousClock().sleep(until: deadline)
                return false
            }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
        try Task.checkCancellation()
        return dismissed
    }

    private func withinAllowance(
        _ duration: Duration, operation: @escaping @MainActor @Sendable () async throws -> Void
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: duration)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await operation() }
            group.addTask {
                // Original XCTest outer failure allowance, with cancellation and joined child work.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.testAllowanceExceeded
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private enum Failure: Error { case testAllowanceExceeded }
}
