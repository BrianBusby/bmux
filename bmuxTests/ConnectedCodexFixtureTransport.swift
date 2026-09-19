import BmuxAgentChat
import Foundation

actor ConnectedCodexFixtureTransport: CodexRPCTransport {
    private let stream: AsyncThrowingStream<Data, any Error>
    private let continuation: AsyncThrowingStream<Data, any Error>.Continuation
    private var malformedQueueAcknowledgment = false
    private var acceptedClientID: String?
    private var loadedThreads = ["thread-a"]
    private(set) var mutationThreads: [String] = []

    init() { (stream, continuation) = AsyncThrowingStream.makeStream() }
    func omitQueueAcknowledgmentID() { malformedQueueAcknowledgment = true }
    func setLoadedThreads(_ threads: [String]) { loadedThreads = threads }

    func send(_ data: Data) async throws {
        let request = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let id = request["id"] else { return }
        let parameters = request["params"] as? [String: Any] ?? [:]
        var result: [String: Any] = [:]
        switch request["method"] as? String {
        case "thread/loaded/list": result = ["data": loadedThreads, "nextCursor": NSNull()]
        case "thread/read": result = ["thread": ["id": "thread-a", "status": ["type": "idle"]]]
        case "thread/queue/add":
            mutationThreads.append(parameters["threadId"] as? String ?? "missing")
            acceptedClientID = parameters["clientUserMessageId"] as? String
            result = malformedQueueAcknowledgment ? [:] : ["queuedSubmission": ["id": "queued-a"]]
        case "thread/queue/list":
            result = ["data": acceptedClientID.map { [["clientUserMessageId": $0, "id": "queued-a"]] } ?? []]
        default: break
        }
        continuation.yield(try JSONSerialization.data(withJSONObject: ["id": id, "result": result]))
    }

    func receive() async throws -> Data {
        var iterator = stream.makeAsyncIterator()
        guard let data = try await iterator.next() else { throw URLError(.networkConnectionLost) }
        return data
    }

    func close() { continuation.finish() }
}
