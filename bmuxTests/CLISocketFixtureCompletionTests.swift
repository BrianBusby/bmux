import Darwin
import Foundation
import Testing

@Suite
struct CLISocketFixtureCompletionTests {
    private enum ProbeError: Error { case operationFailed, readinessDeadline }

    @Test(arguments: [1, 2])
    func completedOneWayFramesAreCapturedBeforeListenerReadiness(clientCount: Int) async throws {
        let path = socketPath()
        let (acknowledgements, written) = AsyncStream<String>.makeStream()
        let server = CLISocketFixture(path: path, responseWritten: written,
                                      deliverReadiness: { _, _ in }, response: { _ in nil })
        let expected = (0..<clientCount).flatMap { client in
            [frame(client: client, event: 0), frame(client: client, event: 1)]
        }
        let (_, commands) = try await server.capture {
            for client in 0..<clientCount {
                try send([frame(client: client, event: 0), frame(client: client, event: 1)], to: path)
            }
        }
        #expect(commands.sorted() == expected.sorted())
        var responses: [String] = []
        for await response in acknowledgements { responses.append(response) }
        #expect(responses.isEmpty, "One-way frames must not synthesize response acknowledgements")
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test
    func completedOneWayFrameIsCapturedBeforeAcceptedClientReadiness() async throws {
        let path = socketPath()
        let (readable, observed) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { observed.finish() }
        let server = CLISocketFixture(path: path, deliverReadiness: { token, destination in
            if token == 0 { destination.yield(token) }
            else { observed.yield(()) }
        }, response: { _ in nil })
        let expected = frame(client: 0, event: 0)
        let (_, commands) = try await server.capture {
            try send([expected], to: path)
            try await requireReadiness(readable)
        }
        #expect(commands == [expected])
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test
    func operationWithoutClientsCompletesAndClosesListener() async throws {
        let path = socketPath()
        let server = CLISocketFixture(path: path, deliverReadiness: { _, _ in }, response: { _ in nil })
        let (_, commands) = try await server.capture { }
        #expect(commands.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test
    func operationFailurePropagatesAndClosesListener() async throws {
        let path = socketPath()
        let server = CLISocketFixture(path: path, deliverReadiness: { _, _ in }, response: { _ in nil })
        await #expect(throws: ProbeError.operationFailed) {
            _ = try await server.capture { throw ProbeError.operationFailed }
        }
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    private func frame(client: Int, event: Int) -> String {
        #"{"method":"feed.push","params":{"workspace_id":"wrong-target","client":\#(client),"event":\#(event)}}"#
    }

    private func socketPath() -> String { "/tmp/capture-\(UUID().uuidString).sock" }

    private func send(_ frames: [String], to path: String) throws {
        let client = socket(AF_UNIX, SOCK_STREAM, 0)
        guard client >= 0 else { throw POSIXError(.ENFILE) }
        defer { Darwin.close(client) }
        var noSignal: Int32 = 1
        try #require(setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8) + [0]
        try #require(pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path))
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        let status = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(client, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        try #require(status == 0)
        // These tiny owned frames fit in the fresh socket buffer; the peer never needs to reply.
        let bytes = Array((frames.joined(separator: "\n") + "\n").utf8)
        let count = bytes.withUnsafeBytes { Darwin.write(client, $0.baseAddress, bytes.count) }
        try #require(count == bytes.count, "Every asserted frame must be fully written before producer completion")
    }

    private func requireReadiness(_ events: AsyncStream<Void>) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in events { return }
                throw ProbeError.readinessDeadline
            }
            group.addTask {
                // A cancellable failure deadline bounds a missing native readiness signal; it is not a settling delay.
                try await Task.sleep(for: .seconds(5))
                throw ProbeError.readinessDeadline
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }
}
