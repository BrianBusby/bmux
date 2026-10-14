import Darwin
import Foundation
import os

/// Owns a socket read source with one outstanding wakeup until its I/O consumer acknowledges it.
final class CLISocketReadiness: Sendable {
    private enum State { case armed, suspended, cancelled }
    private let descriptor: Int32
    // Native socket readiness has no async-native replacement; the fixture exposes AsyncStream events.
    private let source: any DispatchSourceRead
    private let deliver: @Sendable () -> Void
    // Native handler and sole I/O consumer synchronously balance one suspend/cancel transition.
    private let state = OSAllocatedUnfairLock(initialState: State.armed)

    init(descriptor: Int32, deliver: @escaping @Sendable () -> Void) throws {
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0, fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            Darwin.close(descriptor)
            throw error
        }
        self.descriptor = descriptor
        self.deliver = deliver
        self.source = DispatchSource.makeReadSource(fileDescriptor: descriptor)
        source.setEventHandler { [weak self] in self?.signal() }
        source.resume()
    }

    private func signal() {
        let shouldDeliver = state.withLock { value in
            guard value == .armed else { return false }
            value = .suspended
            source.suspend()
            return true
        }
        if shouldDeliver { deliver() }
    }

    func acknowledge() {
        state.withLock { value in
            guard value == .suspended else { return }
            value = .armed
            source.resume()
        }
    }

    // The sole serve task removes each source before calling this joined teardown once.
    func close() async {
        await withCheckedContinuation { continuation in
            state.withLock { value in
                guard value != .cancelled else { continuation.resume(); return }
                source.setCancelHandler { [descriptor] in
                    Darwin.close(descriptor)
                    continuation.resume()
                }
                let wasSuspended = value == .suspended
                value = .cancelled
                if wasSuspended { source.resume() }
                source.cancel()
            }
        }
    }
}
