import Foundation
import Network
import OSLog

/// A single transparent HTTP upgrade and WebSocket byte stream. The provider
/// still authenticates the original header and remains the only RPC owner.
struct CodexRelaySession: Sendable {
    let client: CodexRelayByteStream
    let provider: CodexRelayByteStream
    let handshakeTimeout: Duration
    private let logger = Logger(subsystem: "com.bmux.agent-chat", category: "codex-websocket-relay")

    func run() async {
        client.connection.start(queue: .global(qos: .utility))
        provider.connection.start(queue: .global(qos: .utility))
        // Genuine upgrade deadline; successful upgrade or teardown cancels it.
        let deadline = Task {
            do { try await ContinuousClock().sleep(for: handshakeTimeout) } catch { return }
            close()
        }
        defer { deadline.cancel(); close() }
        await withTaskCancellationHandler {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    do { try await forwardClient() } catch {
                        logger.debug("Client stream ended, error code: \((error as NSError).code)")
                        close()
                    }
                }
                group.addTask {
                    do { try await forwardProvider(deadline: deadline) } catch {
                        logger.debug("Provider stream ended, error code: \((error as NSError).code)")
                        close()
                    }
                }
                await group.next()
                close()
                group.cancelAll()
            }
        } onCancel: { close() }
    }

    func close() {
        client.connection.cancel()
        provider.connection.cancel()
    }

    private func forwardClient() async throws {
        let header = try await client.upgradeHeader()
        // Codex does not negotiate compression. A future extension needs its
        // own compatibility review before this byte-preserving adapter uses it.
        guard !String(decoding: header, as: UTF8.self).lowercased().contains("\r\nsec-websocket-extensions:") else {
            throw URLError(.unsupportedURL)
        }
        try await provider.send(header)
        while !Task.isCancelled {
            var header = try await client.read(2)
            let size = header[1] & 0x7f
            header.append(try await client.read((size == 127 ? 8 : size == 126 ? 2 : 0) + 4))
            let frame = try CodexWebSocketFrame(header: header)
            let fragmentSize = 1024 * 1024
            if frame.length <= fragmentSize {
                try await provider.send(header)
                if frame.length > 0 { try await provider.send(client.read(frame.length)) }
            } else {
                var offset = 0
                while offset < frame.length {
                    let payload = try await client.read(min(fragmentSize, frame.length - offset))
                    let mask = (0..<4).map { _ in UInt8.random(in: .min ... .max) }
                    try await provider.send(frame.fragment(payload: payload, offset: offset, newMask: mask))
                    offset += payload.count
                }
            }
        }
    }

    private func forwardProvider(deadline: Task<Void, Never>) async throws {
        let header = try await provider.upgradeHeader()
        try await client.send(header)
        guard String(decoding: header, as: UTF8.self).hasPrefix("HTTP/1.1 101 ") else { return }
        deadline.cancel()
        while !Task.isCancelled {
            let bytes = try await provider.receive()
            guard !bytes.isEmpty else { return }
            try await client.send(bytes)
        }
    }
}
