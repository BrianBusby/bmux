import Darwin
import Foundation

/// Owns one test's socket lifetime; all capture state stays inside its I/O task.
struct CodexStopMockServer: Sendable {
    let path: String
    let responder: CodexStopMockResponse

    func capture<T: Sendable>(
        operation: () async throws -> T
    ) async throws -> (result: T, commands: [String]) {
        let listener = try bind()
        defer { unlink(path) }
        let (events, continuation) = AsyncStream<Int>.makeStream()
        let capture = Task { try await serve(listener: listener, events: events, continuation: continuation) }
        do {
            let result = try await operation()
            continuation.finish()
            return (result, try await capture.value)
        } catch {
            continuation.finish()
            _ = try? await capture.value
            throw error
        }
    }

    private func bind() throws -> Int32 {
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { throw POSIXError(.ENFILE) }
        do {
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8) + [0]
            guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
                throw POSIXError(.ENAMETOOLONG)
            }
            withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
            let status = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard status == 0, listen(listener, 8) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            return listener
        } catch {
            Darwin.close(listener)
            throw error
        }
    }

    private func serve(
        listener: Int32,
        events: AsyncStream<Int>,
        continuation: AsyncStream<Int>.Continuation
    ) async throws -> [String] {
        var sources: [Int: (descriptor: Int32, source: any DispatchSourceRead)] = [:]
        var pending: [Int: Data] = [:]
        var commands: [String] = []
        var nextToken = 1
        sources[0] = (listener, try readiness(descriptor: listener, token: 0, continuation: continuation))
        do {
            for await token in events {
                guard let connection = sources[token] else { continue }
                if token == 0 {
                    while true {
                        let client = accept(listener, nil, nil)
                        if client < 0, errno == EINTR { continue }
                        if client < 0, errno == EAGAIN || errno == EWOULDBLOCK { break }
                        guard client >= 0 else { throw POSIXError(.EIO) }
                        let clientToken = nextToken
                        nextToken += 1
                        sources[clientToken] = (client, try readiness(
                            descriptor: client, token: clientToken, continuation: continuation
                        ))
                        pending[clientToken] = Data()
                    }
                    continue
                }
                while true {
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    let count = Darwin.read(connection.descriptor, &buffer, buffer.count)
                    if count < 0, errno == EINTR { continue }
                    if count < 0, errno == EAGAIN || errno == EWOULDBLOCK { break }
                    guard count >= 0 else { throw POSIXError(.EIO) }
                    if count == 0 {
                        sources.removeValue(forKey: token)
                        pending.removeValue(forKey: token)
                        await close(connection.source, descriptor: connection.descriptor)
                        break
                    }
                    pending[token, default: Data()].append(contentsOf: buffer.prefix(count))
                    while let newline = pending[token]?.firstIndex(of: 10) {
                        let line = String(decoding: pending[token]!.prefix(upTo: newline), as: UTF8.self)
                        pending[token]!.removeSubrange(...newline)
                        commands.append(line)
                        if let response = try responder.response(to: line) {
                            try await write(response + "\n", to: connection.descriptor)
                        }
                    }
                }
            }
        } catch {
            for connection in sources.values { await close(connection.source, descriptor: connection.descriptor) }
            throw error
        }
        for connection in sources.values { await close(connection.source, descriptor: connection.descriptor) }
        return commands
    }

    private func readiness(
        descriptor: Int32, token: Int, continuation: AsyncStream<Int>.Continuation
    ) throws -> any DispatchSourceRead {
        var noSignal: Int32 = 1
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0,
              fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            Darwin.close(descriptor)
            throw error
        }
        // DispatchSource is the native socket-readiness bridge; callers consume an AsyncStream.
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor)
        source.setEventHandler { continuation.yield(token) }
        source.resume()
        return source
    }

    private func close(_ source: any DispatchSourceRead, descriptor: Int32) async {
        await withCheckedContinuation { continuation in
            source.setCancelHandler {
                Darwin.close(descriptor)
                continuation.resume()
            }
            source.cancel()
        }
    }

    private func writable(_ descriptor: Int32) async {
        await withCheckedContinuation { continuation in
            // One-shot native write readiness bridges backpressure without blocking a task.
            let source = DispatchSource.makeWriteSource(fileDescriptor: descriptor)
            source.setEventHandler { source.cancel() }
            source.setCancelHandler { continuation.resume() }
            source.resume()
        }
    }

    private func write(_ text: String, to descriptor: Int32) async throws {
        let bytes = Array(text.utf8)
        var offset = 0
        while offset < bytes.count {
            let count = bytes.withUnsafeBytes {
                Darwin.write(descriptor, $0.baseAddress!.advanced(by: offset), bytes.count - offset)
            }
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                await writable(descriptor)
                continue
            }
            guard count > 0 else { throw POSIXError(.EIO) }
            offset += count
        }
    }
}
