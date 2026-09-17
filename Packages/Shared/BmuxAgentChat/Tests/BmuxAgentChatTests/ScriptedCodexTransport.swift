import Foundation
@testable import BmuxAgentChat

actor ScriptedCodexTransport: CodexRPCTransport {
    private let loseAcknowledgment: Bool
    private let acceptedClientID: String?
    private let rejectSteer: Bool
    private let stream: AsyncThrowingStream<Data, any Error>
    private let continuation: AsyncThrowingStream<Data, any Error>.Continuation
    private(set) var mutations = 0
    private(set) var expectedTurnID: String?

    init(loseAcknowledgment: Bool = false, rejectSteer: Bool = false, acceptedClientID: String? = nil) {
        self.acceptedClientID = acceptedClientID
        self.loseAcknowledgment = loseAcknowledgment
        self.rejectSteer = rejectSteer
        (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
    }

    func send(_ data: Data) async throws {
        let value = try JSONDecoder().decode(TranscriptJSONValue.self, from: data)
        guard let id = value["id"] else { return }
        var result: TranscriptJSONValue = .object([:])
        switch value["method"]?.string {
        case "thread/queue/add", "turn/steer":
            mutations += 1
            expectedTurnID = value["params"]?["expectedTurnId"]?.string
            if loseAcknowledgment {
                continuation.finish(throwing: URLError(.networkConnectionLost))
                return
            }
            if rejectSteer {
                continuation.yield(try JSONEncoder().encode(TranscriptJSONValue.object(["id": id, "error": .object(["code": .number(-32600)])])))
                return
            }
            result = .object(["queuedSubmission": .object(["id": .string("queued-1")])])
        case "thread/read":
            result = .object(["thread": .object(["id": .string("thread-a"), "turns": .array([])])])
        case "thread/queue/list":
            result = .object(["data": .array(acceptedClientID.map { [.object(["clientUserMessageId": .string($0), "id": .string("queued-reconnected")])] } ?? [])])
        default: break
        }
        continuation.yield(try JSONEncoder().encode(TranscriptJSONValue.object(["id": id, "result": result])))
    }

    func receive() async throws -> Data {
        var iterator = stream.makeAsyncIterator()
        guard let data = try await iterator.next() else { throw URLError(.networkConnectionLost) }
        return data
    }

    func close() { continuation.finish() }
}
