import Darwin
import Foundation

/// Owns one test's socket lifetime; all capture state stays inside its I/O task.
struct CLISocketFixture: Sendable {
    let path: String
    var responseWritten: AsyncStream<String>.Continuation? = nil
    let response: @Sendable (String) throws -> String?
    private let deliverReadiness: @Sendable (Int, AsyncStream<Int>.Continuation) -> Void

    init(
        path: String,
        responseWritten: AsyncStream<String>.Continuation? = nil,
        deliverReadiness: @escaping @Sendable (Int, AsyncStream<Int>.Continuation) -> Void = {
            token, destination in destination.yield(token)
        },
        response: @escaping @Sendable (String) throws -> String?
    ) {
        self.path = path
        self.responseWritten = responseWritten
        self.deliverReadiness = deliverReadiness
        self.response = response
    }

    /// Normal return must join all request producers. The final pass drains bytes already sent
    /// without awaiting future input or response capacity; ordinary serving retains its backpressure policy.
    func capture<T: Sendable>(
        operation: () async throws -> T
    ) async throws -> (result: T, commands: [String]) {
        defer { responseWritten?.finish() }
        let listener = try bind()
        defer { unlink(path) }
        let (events, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let capture = Task { try await serve(listener: listener, events: events, continuation: continuation) }
        do {
            let result = try await operation()
            continuation.yield(Self.completionToken)
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
            // Accepted sockets inherit this at connect time, before the serving task may run.
            var noSignal: Int32 = 1
            guard setsockopt(listener, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
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

    private static let completionToken = -1

    private func serve(
        listener: Int32,
        events: AsyncStream<Int>,
        continuation: AsyncStream<Int>.Continuation
    ) async throws -> [String] {
        var sources: [Int: (descriptor: Int32, source: CLISocketReadiness)] = [:]
        var pending: [Int: Data] = [:]
        var commands: [String] = []
        var nextToken = 1
        sources[0] = (listener, try readiness(descriptor: listener, token: 0, continuation: continuation))
        func acceptPendingClients() throws {
            while true {
                let client = accept(listener, nil, nil)
                if client < 0, errno == EINTR { continue }
                if client < 0, errno == EAGAIN || errno == EWOULDBLOCK { return }
                guard client >= 0 else { throw POSIXError(.EIO) }
                let clientToken = nextToken
                nextToken += 1
                sources[clientToken] = (client, try readiness(
                    descriptor: client, token: clientToken, continuation: continuation
                ))
                pending[clientToken] = Data()
            }
        }

        func readAvailableInput(token: Int, waitsForResponseCapacity: Bool = true) async throws {
            guard let connection = sources[token] else { return }
            var responseWritable = true
            while true {
                var buffer = [UInt8](repeating: 0, count: 4096)
                let count = Darwin.read(connection.descriptor, &buffer, buffer.count)
                if count < 0, errno == EINTR { continue }
                if count < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                    if responseWritable { return }
                    break
                }
                guard count >= 0 else { throw POSIXError(.EIO) }
                if count == 0 { break }
                pending[token, default: Data()].append(contentsOf: buffer.prefix(count))
                while let newline = pending[token]?.firstIndex(of: 10) {
                    let line = String(decoding: pending[token]!.prefix(upTo: newline), as: UTF8.self)
                    pending[token]!.removeSubrange(...newline)
                    commands.append(line)
                    if let response = try response(line), responseWritable {
                        responseWritable = try await write(response + "\n", to: connection.descriptor,
                                                           waitsForCapacity: waitsForResponseCapacity)
                        if responseWritable { responseWritten?.yield(line) }
                    }
                }
            }
            sources.removeValue(forKey: token)
            pending.removeValue(forKey: token)
            await connection.source.close()
        }

        do {
            for await token in events {
                let readySource = sources[token]?.source
                defer { readySource?.acknowledge() }
                if token == Self.completionToken {
                    // Producer completion is independent of delayed DispatchSource delivery.
                    try acceptPendingClients()
                    for clientToken in sources.keys.filter({ $0 != 0 }) {
                        try await readAvailableInput(token: clientToken, waitsForResponseCapacity: false)
                    }
                    break
                }
                if token == 0 { try acceptPendingClients() }
                else { try await readAvailableInput(token: token) }
            }
        } catch {
            for connection in sources.values { await connection.source.close() }
            throw error
        }
        for connection in sources.values { await connection.source.close() }
        return commands
    }

    private func readiness(
        descriptor: Int32, token: Int, continuation: AsyncStream<Int>.Continuation
    ) throws -> CLISocketReadiness {
        try CLISocketReadiness(descriptor: descriptor) { [deliverReadiness] in
            deliverReadiness(token, continuation)
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

    private func write(_ text: String, to descriptor: Int32, waitsForCapacity: Bool) async throws -> Bool {
        let bytes = Array(text.utf8)
        var offset = 0
        while offset < bytes.count {
            let count = bytes.withUnsafeBytes {
                Darwin.write(descriptor, $0.baseAddress!.advanced(by: offset), bytes.count - offset)
            }
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                // Completion must not wait for a peer to read a response after its producer returned.
                guard waitsForCapacity else { throw POSIXError(.EWOULDBLOCK) }
                await writable(descriptor)
                continue
            }
            // A CLI can cancel an in-flight resize after its bridge closes. Do not acknowledge
            // that response; the caller still drains any complete queued input before closing.
            if count < 0, errno == EPIPE { return false }
            guard count > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            offset += count
        }
        return true
    }
}
