import Foundation
import Network

/// Compatibility adapter for Codex clients that emit image inputs in a single
/// frame larger than the provider's 16 MiB limit. Streams masked data frames in
/// 1 MiB fragments; preserves the HTTP authorization header and every RPC byte.
///
/// The host owner must call ``stop()`` on rollback, process exit, or workspace
/// close. No credential is stored here, no message is replayed, and no external
/// network address is accepted. Tests can inject a loopback provider fixture.
public actor CodexWebSocketRelay {
    private let port: NWEndpoint.Port
    private let handshakeTimeout: Duration
    private var listener: NWListener?
    private var sessions: [UUID: (CodexRelaySession, Task<Void, Never>)] = [:]
    private var stopped = false

    /// Creates a relay for an authenticated provider bound to `127.0.0.1`.
    /// - Parameters:
    ///   - endpoint: Plain loopback WebSocket URL with an explicit port.
    ///   - handshakeTimeout: Bound for listener startup and each HTTP upgrade.
    /// - Throws: `URLError.unsupportedURL` for an unsupported endpoint.
    public init(endpoint: URL, handshakeTimeout: Duration = .seconds(15)) throws {
        guard endpoint.scheme == "ws", endpoint.host == "127.0.0.1",
              endpoint.user == nil, endpoint.password == nil, endpoint.query == nil,
              endpoint.fragment == nil, endpoint.path.isEmpty || endpoint.path == "/",
              let number = endpoint.port, let port = NWEndpoint.Port(rawValue: UInt16(exactly: number) ?? 0),
              port.rawValue != 0 else { throw URLError(.unsupportedURL) }
        self.port = port
        self.handshakeTimeout = handshakeTimeout
    }

    deinit {
        listener?.cancel()
        for (session, task) in sessions.values { session.close(); task.cancel() }
    }

    /// Starts once and returns a loopback URL for the original TUI's `--remote`.
    /// The provider, not the adapter, validates authentication and Origin.
    /// - Throws: A listener error or cancellation if startup cannot complete.
    public func start() async throws -> URL {
        guard listener == nil, !stopped else { throw URLError(.cancelled) }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        let (states, continuation) = AsyncStream<NWListener.State>.makeStream(bufferingPolicy: .bufferingNewest(4))
        listener.stateUpdateHandler = { continuation.yield($0) }
        listener.newConnectionHandler = { [weak self] connection in
            Task {
                guard let self else { connection.cancel(); return }
                await self.accept(connection)
            }
        }
        // Genuine bind deadline; canceled on readiness, cancellation, or failure.
        let deadline = Task {
            do { try await ContinuousClock().sleep(for: handshakeTimeout) } catch { return }
            listener.cancel()
            continuation.finish()
        }
        defer { deadline.cancel() }
        listener.start(queue: .global(qos: .utility))
        do {
            return try await withTaskCancellationHandler {
                for await state in states {
                    try Task.checkCancellation()
                    switch state {
                    case .ready:
                        guard !stopped, let port = listener.port else { throw URLError(.cancelled) }
                        return URL(string: "ws://127.0.0.1:\(port.rawValue)")!
                    case .failed(let error): throw error
                    case .cancelled: throw URLError(.cancelled)
                    default: break
                    }
                }
                throw URLError(.timedOut)
            } onCancel: { listener.cancel(); continuation.finish() }
        } catch {
            stop()
            throw error
        }
    }

    /// Closes all connections and the listener. Safe to call more than once.
    public func stop() {
        stopped = true
        listener?.cancel()
        listener = nil
        for (session, task) in sessions.values { session.close(); task.cancel() }
        sessions.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        guard !stopped, sessions.count < 8 else { connection.cancel(); return }
        let provider = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        let session = CodexRelaySession(client: .init(connection: connection), provider: .init(connection: provider),
                                       handshakeTimeout: handshakeTimeout)
        let id = UUID()
        let task = Task { [weak self] in
            await session.run()
            await self?.removeSession(id)
        }
        sessions[id] = (session, task)
    }

    private func removeSession(_ id: UUID) { sessions.removeValue(forKey: id) }
}
