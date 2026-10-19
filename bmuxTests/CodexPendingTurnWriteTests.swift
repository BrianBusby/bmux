import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct CodexPendingTurnWriteTests {
    @Test func submitBlocksReentrantTurnWhileWriteIsPending() async throws {
        try await exercisePendingWrite()
    }

    private func exercisePendingWrite(timeout: Duration = .seconds(1)) async throws {
        var sentLines: [String] = []
        let writes = AsyncStream<String>.makeStream()
        let turnRelease = AsyncStream<Void>.makeStream()
        defer {
            writes.continuation.finish()
            turnRelease.continuation.finish()
        }
        let session = CodexAppServerSession(
            workingDirectory: nil,
            writeData: { @MainActor data in
                let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
                let method = try #require(object["method"] as? String)
                if method == "turn/start" {
                    writes.continuation.yield(method)
                    for await _ in turnRelease.stream {
                        break
                    }
                }
                sentLines.append(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines))
                if method != "turn/start" {
                    writes.continuation.yield(method)
                }
            },
            outputSink: { _, _ in }
        )
        try await session.start()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let cleanup: @MainActor @Sendable () -> Void = {
            turnRelease.continuation.finish()
            session.consumeStdout(#"{"method":"error","params":{"error":{"message":"owned test cleanup"}}}"# + "\n")
            writes.continuation.finish()
        }
        let expire: @MainActor @Sendable () async throws -> Void = {
            // The old yield loop was unbounded; cleanup also runs on parent cancellation.
            defer { cleanup() }
            try await ContinuousClock().sleep(until: deadline)
            throw PendingWriteFailure.timedOut
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                try await submitAndRelease(session, writes: writes.stream, release: turnRelease.continuation, cleanup: cleanup)
            }
            group.addTask { try await expire() }
            try await group.next()
        }
        #expect(sentLines.count == 4)
        let line = try #require(sentLines.last)
        let object = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        let params = try #require(object["params"] as? [String: Any])
        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.first?["text"] as? String == "first prompt")
    }

    private func submitAndRelease(
        _ session: CodexAppServerSession,
        writes: AsyncStream<String>,
        release: AsyncStream<Void>.Continuation,
        cleanup: @escaping @MainActor @Sendable () -> Void
    ) async throws {
        session.consumeStdout(
            #"{"id":1,"result":{"userAgent":"codex","codexHome":"/tmp","platformFamily":"unix","platformOs":"macos"}}"# + "\n"
        )
        var iterator = writes.makeAsyncIterator()
        var sawThreadStart = false
        while let method = await iterator.next() {
            if method == "thread/start" {
                sawThreadStart = true
                break
            }
        }
        guard sawThreadStart, !Task.isCancelled else { throw CancellationError() }
        // This MainActor writer does not suspend for thread/start; its request ID is stored before consumption resumes.
        session.consumeStdout(#"{"id":2,"result":{"thread":{"id":"thread-1"}}}"# + "\n")
        let first = Task { @MainActor in try await session.submit("first prompt") }
        do {
            var sawTurnStart = false
            while let method = await iterator.next() {
                if method == "turn/start" {
                    sawTurnStart = true
                    break
                }
            }
            guard sawTurnStart, !Task.isCancelled else { throw CancellationError() }
            await #expect(throws: (any Error).self) { try await session.submit("second prompt") }
            release.yield(())
            try await first.value
        } catch {
            cleanup()
            first.cancel()
            _ = await first.result
            throw error
        }
    }

    private enum PendingWriteFailure: Error { case timedOut }
}
