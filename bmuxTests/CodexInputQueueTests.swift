import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct CodexInputQueueTests {
    @Test func inputQueueBeforeThreadIsBounded() async throws {
        try await exerciseQueue()
    }

    private func exerciseQueue(timeout: Duration = .seconds(1)) async throws {
        var sentLines: [String] = []
        let entered = AsyncStream<Void>.makeStream()
        let writes = AsyncStream<String>.makeStream()
        defer {
            entered.continuation.finish()
            writes.continuation.finish()
        }
        let session = CodexAppServerSession(
            workingDirectory: nil,
            writeData: { @MainActor data in
                let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
                sentLines.append(line)
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let method = object?["method"] as? String { writes.continuation.yield(method) }
            },
            outputSink: { _, _ in }
        )
        try await session.start()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await submitAndBind(session, entered: entered, writes: writes.stream) }
            group.addTask { try await expire(session, deadline: deadline, entered: entered.continuation, writes: writes.continuation) }
            try await group.next()
        }
        #expect(sentLines.count == 4)
        let data = try #require(sentLines.last?.data(using: .utf8))
        let turnStart = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(turnStart["method"] as? String == "turn/start")
        let params = try #require(turnStart["params"] as? [String: Any])
        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.first?["text"] as? String == "first prompt")
    }

    private func submitAndBind(
        _ session: CodexAppServerSession,
        entered: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation),
        writes: AsyncStream<String>
    ) async throws {
        let first = Task { @MainActor in
            // Same-actor submit reaches its continuation before this signal's consumer resumes.
            entered.continuation.yield(())
            try await session.submit("first prompt")
        }
        do {
            var entry = entered.stream.makeAsyncIterator()
            guard await entry.next() != nil else { throw CancellationError() }
            await #expect(throws: (any Error).self) { try await session.submit("second prompt") }
            session.consumeStdout(#"{"id":1,"result":{"userAgent":"codex","codexHome":"/tmp","platformFamily":"unix","platformOs":"macos"}}"# + "\n")
            var sawThreadStart = false
            for await method in writes where method == "thread/start" {
                sawThreadStart = true
                break
            }
            guard sawThreadStart else { throw CancellationError() }
            session.consumeStdout(#"{"id":2,"result":{"thread":{"id":"thread-1"}}}"# + "\n")
            try await first.value
        } catch {
            failStartup(session)
            _ = await first.result
            throw error
        }
    }

    private func expire(
        _ session: CodexAppServerSession,
        deadline: ContinuousClock.Instant,
        entered: AsyncStream<Void>.Continuation,
        writes: AsyncStream<String>.Continuation
    ) async throws {
        defer {
            failStartup(session)
            entered.finish()
            writes.finish()
        }
        // New bounded failure containment; cancellation must also release the owned startup wait.
        try await ContinuousClock().sleep(until: deadline)
        throw QueueFailure.timedOut
    }

    private func failStartup(_ session: CodexAppServerSession) {
        // Canceling a Task cannot release the owner's checked queue continuation.
        session.consumeStdout(#"{"method":"error","params":{"error":{"message":"owned test cleanup"}}}"# + "\n")
    }

    private enum QueueFailure: Error { case timedOut }
}
