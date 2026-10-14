import Darwin
import Foundation

/// Receives bytes with a cached receive timeout; the caller owns and closes the borrowed descriptor.
struct CLISocketReceiver {
    private(set) var configuredTimeout: TimeInterval?

    mutating func configure(descriptor: Int32, timeout: TimeInterval, interval: timeval) throws {
        if let code = setTimeout(descriptor: descriptor, interval: interval) {
            throw configurationFailure(code)
        }
        configuredTimeout = timeout
    }

    mutating func read(
        descriptor: Int32, buffer: UnsafeMutableRawPointer, count: Int,
        timeout: TimeInterval, interval: timeval
    ) throws -> Int {
        if configuredTimeout != timeout {
            if let code = setTimeout(descriptor: descriptor, interval: interval) {
                let failure = configurationFailure(code)
                guard code == EINVAL else { throw failure }
                // Darwin can reject SO_RCVTIMEO after peer close. Consume only bytes or EOF
                // already available; a failed nonblocking read retains the configuration error.
                let received = Darwin.recv(descriptor, buffer, count, MSG_DONTWAIT)
                guard received >= 0 else { throw failure }
                return received
            }
            configuredTimeout = timeout
        }
        return Darwin.read(descriptor, buffer, count)
    }

    private func setTimeout(descriptor: Int32, interval: timeval) -> Int32? {
        var interval = interval
        let result = withUnsafePointer(to: &interval) { pointer in
            setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, pointer, socklen_t(MemoryLayout<timeval>.size))
        }
        return result == 0 ? nil : errno
    }

    private func configurationFailure(_ code: Int32) -> CLIError {
        let reason = String(cString: strerror(code))
        return CLIError(message: "Failed to configure socket receive timeout (\(reason), errno \(code))")
    }
}
