import Darwin
import Foundation

/// Owns a single loopback bridge, closing at EOF or after the socket fixture has written a resize acknowledgement.
struct SSHPTYLifecycleBridge {
    private enum Event: Sendable { case accept, input, resized }
    let waitsForResize: Bool
    let resets: Bool

    /// The operation must finish its response producer before returning normally.
    func capture<T: Sendable>(
        responses: AsyncStream<String>, operation: (Int) async throws -> T
    ) async throws -> (result: T, handshake: String, closed: Bool, resized: Bool, inputEnded: Bool) {
        let (listener, port) = try bind()
        let (events, continuation) = AsyncStream<Event>.makeStream()
        let bridge = Task { try await serve(listener: listener, events: events, continuation: continuation) }
        let acknowledgements = Task {
            for await line in responses where line.contains("workspace.remote.pty_resize") {
                continuation.yield(.resized)
            }
        }
        do {
            let result = try await operation(port)
            // Preserve queued response observations before closing their destination stream.
            await acknowledgements.value
            continuation.finish()
            let trace = try await bridge.value
            return (result, trace.0, trace.1, trace.2, trace.3)
        } catch {
            continuation.finish()
            acknowledgements.cancel()
            await acknowledgements.value
            _ = try? await bridge.value
            throw error
        }
    }

    private func bind() throws -> (Int32, Int) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.ENFILE) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let status = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameStatus = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        guard status == 0, nameStatus == 0, listen(fd, 1) == 0 else {
            Darwin.close(fd); throw POSIXError(.EIO)
        }
        return (fd, Int(UInt16(bigEndian: address.sin_port)))
    }

    private func serve(
        listener: Int32, events: AsyncStream<Event>, continuation: AsyncStream<Event>.Continuation
    ) async throws -> (String, Bool, Bool, Bool) {
        var sources: [(Int32, any DispatchSourceRead)] = []
        var client: Int32?
        var pending = Data(), handshake = ""
        var resized = false, inputEnded = false
        var inputSuspended = false
        do {
            sources.append((listener, try readiness(listener, event: .accept, continuation: continuation)))
            for await event in events {
                switch event {
                case .accept:
                    guard client == nil else { continue }
                    let fd = accept(listener, nil, nil)
                    if fd < 0, errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                    guard fd >= 0 else { throw POSIXError(.EIO) }
                    client = fd
                    sources.append((fd, try readiness(fd, event: .input, continuation: continuation)))
                case .resized: resized = true
                case .input:
                    guard !inputEnded else { continue }
                    guard let client else { continue }
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    let count = Darwin.read(client, &buffer, buffer.count)
                    if count < 0, errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                    guard count >= 0 else { throw POSIXError(.EIO) }
                    if count == 0 {
                        inputEnded = true
                        sources.last?.1.suspend()
                        inputSuspended = true
                    }
                    else { pending.append(contentsOf: buffer.prefix(count)) }
                    if handshake.isEmpty, let newline = pending.firstIndex(of: 10) {
                        handshake = String(decoding: pending.prefix(upTo: newline), as: UTF8.self)
                        pending.removeSubrange(...newline)
                        try await writeReady(to: client)
                    }
                }
                if !handshake.isEmpty, !waitsForResize || resized, !resets || inputEnded {
                    if resets, let client {
                        var option = linger(l_onoff: 1, l_linger: 0)
                        guard setsockopt(client, SOL_SOCKET, SO_LINGER, &option, socklen_t(MemoryLayout<linger>.size)) == 0 else {
                            throw POSIXError(.EIO)
                        }
                    }
                    if inputSuspended { sources.last?.1.resume() }
                    for (fd, source) in sources { await close(fd, source: source) }
                    return (handshake, true, resized, inputEnded)
                }
            }
        } catch {
            if inputSuspended { sources.last?.1.resume() }
            for (fd, source) in sources { await close(fd, source: source) }
            throw error
        }
        if inputSuspended { sources.last?.1.resume() }
        for (fd, source) in sources { await close(fd, source: source) }
        return (handshake, false, resized, inputEnded)
    }

    private func readiness(
        _ fd: Int32, event: Event, continuation: AsyncStream<Event>.Continuation
    ) throws -> any DispatchSourceRead {
        // Accepted sockets inherit SO_NOSIGPIPE; setting it after a peer closes can return EINVAL.
        var noSignal: Int32 = 1
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0, fcntl(fd, F_SETFD, FD_CLOEXEC) == 0,
              (event != .accept || setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0) else {
            Darwin.close(fd); throw POSIXError(.EIO)
        }
        // Native socket readiness is consumed by the bridge task; cancellation joins descriptor closure.
        let source = DispatchSource.makeReadSource(fileDescriptor: fd)
        source.setEventHandler { continuation.yield(event) }
        source.resume()
        return source
    }

    private func close(_ fd: Int32, source: any DispatchSourceRead) async {
        await withCheckedContinuation { continuation in
            source.setCancelHandler { Darwin.close(fd); continuation.resume() }
            source.cancel()
        }
    }

    private func writeReady(to fd: Int32) async throws {
        let bytes = Array("{\"type\":\"ready\",\"attachment_token\":\"attach-token\"}\n".utf8)
        var offset = 0
        while offset < bytes.count {
            let count = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: offset), bytes.count - offset) }
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                await withCheckedContinuation { continuation in
                    // One-shot write readiness handles backpressure without blocking an executor.
                    let source = DispatchSource.makeWriteSource(fileDescriptor: fd)
                    source.setEventHandler { source.cancel() }
                    source.setCancelHandler { continuation.resume() }
                    source.resume()
                }
                continue
            }
            guard count > 0 else { throw POSIXError(.EIO) }
            offset += count
        }
    }
}
