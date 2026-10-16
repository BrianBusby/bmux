import AppKit

/// Observes actual native search-field ownership without requesting focus or waiting for text editing.
@MainActor
struct TerminalSearchFieldFocusObservation {
    private let duration: Duration

    init(duration: Duration) {
        self.duration = duration
    }

    func wait(of field: NSTextField, in window: NSWindow) async throws {
        let deadline = ContinuousClock.now.advanced(by: duration)
        let (results, signal) = AsyncStream<FocusResult>.makeStream(bufferingPolicy: .bufferingOldest(1))
        // AppKit exposes native responder changes through KVO; editing notifications do not report focus alone.
        let observation = window.observe(\.firstResponder, options: [.new]) { [weak window, weak field] _, _ in
            // NSWindow responder mutations and their synchronous KVO callbacks are main-thread AppKit work.
            MainActor.assumeIsolated {
                guard let window, let field, owns(window.firstResponder, field: field) else { return }
                signal.yield(.focused(.now))
                signal.finish()
            }
        }
        defer { observation.invalidate(); signal.finish() }
        if owns(window.firstResponder, field: field) {
            signal.yield(.focused(.now))
            signal.finish()
        }
        let result = await withTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { await expire(at: deadline, signal: signal) }
            var iterator = results.makeAsyncIterator()
            return await iterator.next()
        }
        try Task.checkCancellation()
        guard let result else { throw CancellationError() }
        switch result {
        case .focused(let arrival):
            guard arrival <= deadline else { throw Failure.focusTimedOut }
        case .failed(let error): throw error
        }
    }

    private func expire(at deadline: ContinuousClock.Instant, signal: AsyncStream<FocusResult>.Continuation) async {
        do {
            // Preserve the original bounded focus wait; cancellation joins this failure timer.
            try await ContinuousClock().sleep(until: deadline)
            signal.yield(.failed(Failure.focusTimedOut))
        } catch is CancellationError { return }
        catch { signal.yield(.failed(error)) }
        signal.finish()
    }

    private func owns(_ responder: NSResponder?, field: NSTextField) -> Bool {
        if responder === field { return true }
        guard let editor = responder as? NSTextView else { return false }
        return editor.isFieldEditor && editor.delegate as? NSTextField === field
    }

    private enum FocusResult: Sendable {
        case focused(ContinuousClock.Instant)
        case failed(any Error)
    }
    private enum Failure: Error { case focusTimedOut }
}
