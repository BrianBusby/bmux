#if DEBUG
import Foundation

/// Per-panel invalidation signals; lifecycle decisions remain with BrowserPanel.
@MainActor
final class BrowserDeveloperToolsLifecycleObservation {
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var isFinished = false

    func changes() -> (id: UUID, events: AsyncStream<Void>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        guard !isFinished else {
            continuation.finish()
            return (id, stream)
        }
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.continuations.removeValue(forKey: id) }
        }
        continuation.yield(())
        return (id, stream)
    }

    func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)?.finish()
    }

    func publish() {
        for continuation in continuations.values { continuation.yield(()) }
    }

    func finish() {
        isFinished = true
        for continuation in continuations.values { continuation.finish() }
        continuations.removeAll()
    }

    deinit {
        for continuation in continuations.values { continuation.finish() }
    }
}
#endif
