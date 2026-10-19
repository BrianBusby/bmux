import Foundation
import Testing

/// Owns the distributed-notification subscription and its bounded delivery wait.
@MainActor
final class ThemeReloadObservation {
    struct Reload: Sendable {
        let bundleIdentifier: String?
        let phase: String?
        let socketPath: String?
    }

    private let events: AsyncStream<Void>
    private let signal: AsyncStream<Void>.Continuation
    private var observer: NSObjectProtocol?
    private(set) var reloads: [Reload] = []

    init(bundleIdentifier: String) {
        (events, signal) = AsyncStream.makeStream()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.bmuxterm.themes.reload-config"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reload = Reload(
                bundleIdentifier: notification.userInfo?["bundleIdentifier"] as? String,
                phase: notification.userInfo?["phase"] as? String,
                socketPath: notification.userInfo?["socketPath"] as? String
            )
            // The observer explicitly delivers on OperationQueue.main.
            MainActor.assumeIsolated {
                guard let self, reload.bundleIdentifier == bundleIdentifier else { return }
                self.reloads.append(reload)
                self.signal.yield(())
            }
        }
    }

    func wait(deadline: Duration) async throws {
        let events = events
        let end = ContinuousClock.now.advanced(by: deadline)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Preserve the original notification failure bound; this is not a settling delay.
                try await ContinuousClock().sleep(until: end)
                throw Failure.timedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    func close() {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        observer = nil
        signal.finish()
    }

    private enum Failure: Error { case timedOut }
}
