import Darwin
import Foundation

/// Drains an owned pipe or PTY asynchronously while the CLI runs, without cooperative blocking reads.
final class CLIOutputChannel {
    let path: String
    private let descriptor: Int32
    private let slave: Int32?
    private let pipePath: String?

    init(root: URL, terminal: Bool) throws {
        if terminal {
            var master: Int32 = -1, child: Int32 = -1
            var size = winsize(ws_row: 43, ws_col: 132, ws_xpixel: 0, ws_ypixel: 0)
            guard openpty(&master, &child, nil, nil, &size) == 0 else { throw POSIXError(.EIO) }
            guard let name = ttyname(child) else {
                Darwin.close(master); Darwin.close(child)
                throw POSIXError(.EIO)
            }
            descriptor = master; slave = child; path = String(cString: name); pipePath = nil
        } else {
            path = root.appendingPathComponent("stdout.pipe").path
            guard mkfifo(path, 0o600) == 0 else { throw POSIXError(.EIO) }
            let fd = Darwin.open(path, O_RDWR | O_NONBLOCK)
            guard fd >= 0 else { unlink(path); throw POSIXError(.EIO) }
            descriptor = fd; slave = nil; pipePath = path
        }
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0,
              fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0,
              slave.map({ fcntl($0, F_SETFD, FD_CLOEXEC) == 0 }) ?? true else {
            // All properties are initialized here; deinit owns cleanup even when this initializer throws.
            throw POSIXError(.EIO)
        }
    }

    deinit {
        Darwin.close(descriptor)
        if let slave { Darwin.close(slave) }
        if let pipePath { unlink(pipePath) }
    }

    func capture<T: Sendable>(operation: () async throws -> T) async throws -> (T, String) {
        let (events, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        // Native FD readiness is delivered as an AsyncStream, with cancellation joined before returning.
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor)
        source.setEventHandler { continuation.yield(()) }
        source.resume()
        let fd = descriptor
        let reader = Task<Data, Error> {
            var data = Data()
            for await _ in events { try CLIOutputChannel.drain(fd, into: &data) }
            try CLIOutputChannel.drain(fd, into: &data)
            return data
        }
        let result: T
        do { result = try await operation() }
        catch {
            await stop(source, continuation: continuation)
            _ = try? await reader.value
            throw error
        }
        await stop(source, continuation: continuation)
        return (result, String(decoding: try await reader.value, as: UTF8.self))
    }

    private func stop(_ source: any DispatchSourceRead, continuation: AsyncStream<Void>.Continuation) async {
        await withCheckedContinuation { finished in
            source.setCancelHandler { continuation.finish(); finished.resume() }
            source.cancel()
        }
    }

    private static func drain(_ fd: Int32, into data: inout Data) throws {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK { return }
            guard count >= 0 else { throw POSIXError(.EIO) }
            if count == 0 { return }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
}
