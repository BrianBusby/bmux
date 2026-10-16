import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
final class CodexApprovalResponseTests {
    private var sentLines: [String] = []

    @Test func approvalRequestsOnlyAutoApproveForFullAccessMode() async throws {
        try await exerciseApprovals(timeout: .seconds(1))
    }

    private func exerciseApprovals(timeout: Duration) async throws {
        let writes = AsyncStream<String>.makeStream()
        defer { writes.continuation.finish() }
        let session = CodexAppServerSession(workingDirectory: nil, writeData: { @MainActor data in
            self.sentLines.append(String(decoding: data, as: UTF8.self))
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            writes.continuation.yield(object["id"] as? String ?? object["method"] as? String ?? "initialize")
        }, outputSink: { _, _ in })
        try await session.start()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let cleanup: @MainActor @Sendable () -> Void = {
            // The owner's queued startup continuation is not released by task cancellation alone.
            session.consumeStdout(#"{"method":"error","params":{"error":{"message":"owned test cleanup"}}}"# + "\n")
            writes.continuation.finish()
        }
        let expire: @MainActor @Sendable () async throws -> Void = {
            defer { cleanup() }
            // New finite observation containment; the old positional read had no explicit deadline.
            try await ContinuousClock().sleep(until: deadline)
            throw ApprovalFailure.timedOut
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await self.submitAndObserve(session, writes: writes.stream) }
            group.addTask { try await expire() }
            try await group.next()
        }
        try Task.checkCancellation()

        let defaultCommandResult = try response(id: "cmd-1")
        #expect(defaultCommandResult["decision"] as? String == "decline")
        let defaultPermissionResult = try response(id: "perm-1")
        let defaultPermissions = try #require(defaultPermissionResult["permissions"] as? [String: Any])
        #expect(defaultPermissions.isEmpty)
        let fullAccessCommandResult = try response(id: "cmd-2")
        #expect(fullAccessCommandResult["decision"] as? String == "acceptForSession")
        let fullAccessPermissionResult = try response(id: "perm-2")
        let fullAccessPermissions = try #require(fullAccessPermissionResult["permissions"] as? [String: Any])
        let networkPermissions = try #require(fullAccessPermissions["network"] as? [String: Any])
        #expect(networkPermissions["enabled"] as? Bool == true)
    }

    private func submitAndObserve(_ session: CodexAppServerSession, writes: AsyncStream<String>) async throws {
        session.consumeStdout(
            #"{"id":1,"result":{"userAgent":"codex","codexHome":"/tmp","platformFamily":"unix","platformOs":"macos"}}"# + "\n")
        var iterator = writes.makeAsyncIterator()
        var sawThreadStart = false
        while let event = await iterator.next() {
            if event == "thread/start" { sawThreadStart = true; break }
        }
        guard sawThreadStart, !Task.isCancelled else { throw CancellationError() }
        // The same-actor writer does not suspend; request registration finishes before this consumer resumes.
        session.consumeStdout(#"{"id":2,"result":{"thread":{"id":"thread-1"}}}"# + "\n")
        try await session.submit("default prompt", permissionMode: .standard)
        session.consumeStdout(
            #"{"id":"cmd-1","method":"item/commandExecution/requestApproval","params":{"threadId":"thread-1"}}"# + "\n")
        session.consumeStdout(
            #"{"id":"perm-1","method":"item/permissions/requestApproval","params":{"permissions":{"network":{"enabled":true}}}}"# + "\n")
        await #expect(throws: (any Error).self) {
            try await session.submit("blocked full access prompt", permissionMode: .fullAccess)
        }
        session.consumeStdout(#"{"method":"turn/completed","params":{"threadId":"thread-1"}}"# + "\n")
        try await session.submit("full access prompt", permissionMode: .fullAccess)
        session.consumeStdout(
            #"{"id":"cmd-2","method":"item/commandExecution/requestApproval","params":{"threadId":"thread-1"}}"# + "\n")
        session.consumeStdout(
            #"{"id":"perm-2","method":"item/permissions/requestApproval","params":{"permissions":{"network":{"enabled":true}}}}"# + "\n")
        var pending: Set<String> = ["cmd-1", "perm-1", "cmd-2", "perm-2"]
        while !pending.isEmpty, let event = await iterator.next() { pending.remove(event) }
        guard pending.isEmpty, !Task.isCancelled else { throw CancellationError() }
    }

    private func response(id: String) throws -> [String: Any] {
        let objects = try sentLines.map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
        let matches = objects.filter { $0["id"] as? String == id }
        #expect(matches.count == 1)
        let object = try #require(matches.first)
        return try #require(object["result"] as? [String: Any])
    }

    private enum ApprovalFailure: Error { case timedOut }
}
