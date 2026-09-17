import Foundation

/// JSON-RPC multiplexing for one connection. Disconnects fail pending calls;
/// callers must reconcile mutations rather than replay them on a new connection.
public actor CodexRPCConnection {
    private let transport: any CodexRPCTransport
    private let requestTimeout: Duration
    private var reader: Task<Void, Never>?
    private var pending: [String: CheckedContinuation<Data, any Error>] = [:]
    private var deadlines: [String: Task<Void, Never>] = [:]
    private var connected = false
    private var observers: [UUID: AsyncStream<Data>.Continuation] = [:]

    public init(transport: any CodexRPCTransport, requestTimeout: Duration = .seconds(15)) {
        self.transport = transport
        self.requestTimeout = requestTimeout
    }

    public func start() async throws {
        guard reader == nil else { return }
        connected = true
        reader = Task { [weak self, transport] in
            do {
                while !Task.isCancelled {
                    let data = try await transport.receive()
                    await self?.consume(data)
                }
            } catch {
                await self?.disconnect()
            }
        }
        do {
            _ = try await request(method: "initialize", params: Data(#"{"clientInfo":{"name":"bmux-connected-chat","version":"1"},"capabilities":{"experimentalApi":true,"requestAttestation":false}}"#.utf8))
            try await transport.send(Data(#"{"method":"initialized","params":{}}"#.utf8))
        } catch {
            await disconnect()
            throw error
        }
    }

    /// Raw provider events are transient, bounded, and never logged here.
    public func events() -> AsyncStream<Data> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(128))
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        return stream
    }

    public func request(method: String, params: Data) async throws -> Data {
        guard connected else { throw CodexControlError.disconnected }
        guard let parameters = try? JSONDecoder().decode(TranscriptJSONValue.self, from: params) else {
            throw CodexControlError.invalidInput
        }
        let id = UUID().uuidString
        let message = try JSONEncoder().encode(TranscriptJSONValue.object([
            "id": .string(id), "method": .string(method), "params": parameters
        ]))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                deadlines[id] = Task { [weak self, requestTimeout] in
                    // A bounded request deadline; cancellation retires it when the response arrives.
                    do { try await ContinuousClock().sleep(for: requestTimeout) } catch { return }
                    await self?.fail(id, error: CodexControlError.uncertainDelivery)
                }
                Task { [weak self, transport] in
                    do { try await transport.send(message) }
                    catch { await self?.fail(id, error: CodexControlError.uncertainDelivery) }
                }
            }
        } onCancel: {
            Task { await self.fail(id, error: CodexControlError.uncertainDelivery) }
        }
    }

    public func disconnect() async {
        connected = false
        reader?.cancel()
        reader = nil
        for id in Array(pending.keys) { fail(id, error: CodexControlError.uncertainDelivery) }
        for observer in observers.values { observer.finish() }
        observers.removeAll()
        await transport.close()
    }

    private func consume(_ data: Data) {
        guard let object = try? JSONDecoder().decode(TranscriptJSONValue.self, from: data) else {
            return
        }
        // Server requests belong to the original TUI. Never synthesize an answer.
        if object["method"] != nil {
            for observer in observers.values { observer.yield(data) }
            return
        }
        guard let id = object["id"]?.string, let continuation = pending.removeValue(forKey: id) else { return }
        deadlines.removeValue(forKey: id)?.cancel()
        if object["error"] != nil {
            continuation.resume(throwing: CodexControlError.rejected)
        } else if let result = object["result"], let encoded = try? JSONEncoder().encode(result) {
            continuation.resume(returning: encoded)
        } else {
            continuation.resume(throwing: CodexControlError.invalidResponse)
        }
    }

    private func fail(_ id: String, error: CodexControlError) {
        deadlines.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
}
