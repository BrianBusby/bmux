import Foundation
@preconcurrency import Network

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the two in-flight callbacks and joins their real response-task tails.
actor MobileHostBatchedFrameFixture {
    private enum SignalPhase { case firstRecorded, secondAuthorizeStarted }
    private enum Failure: Error { case timedOut(SignalPhase) }

    private let firstRecorded = AsyncStream<Void>.makeStream()
    private let secondAuthorizeStarted = AsyncStream<Void>.makeStream()
    private let firstMayClose = AsyncStream<Void>.makeStream()
    private let secondMayReturn = AsyncStream<Void>.makeStream()
    private var session: MobileHostConnection?
    private var recordedMethods: [String] = []

    func process(_ batch: Data) async throws -> [String] {
        let connection = MobileHostConnection(
            id: UUID(),
            connection: NWConnection(host: .ipv4(.loopback), port: 9, using: .tcp),
            authorizeRequest: { [self] request in
                if request.id as? String == "second" {
                    secondAuthorizeStarted.continuation.finish()
                    for await _ in secondMayReturn.stream {}
                }
                return nil
            },
            onAuthorizedRequest: { [self] request in
                await recordAndClose(request.method)
            },
            handleRequest: { _ in .ok([:]) },
            onClose: { _ in }
        )
        session = connection
        defer {
            releaseSignals()
            session = nil
        }
        await connection.debugHandleReceiveDataForTesting(batch)
        do {
            try await connection.drainResponsesWhilePerformingForTesting { [self] in
                do {
                    try await Self.waitForSignal(firstRecorded.stream, phase: .firstRecorded)
                    try await Self.waitForSignal(secondAuthorizeStarted.stream, phase: .secondAuthorizeStarted)
                    firstMayClose.continuation.finish()
                } catch {
                    // Release both callbacks before close cancels them. The outer
                    // drain already owns their handles and joins every return path.
                    await releaseSignals()
                    await connection.close(reason: "batched frame fixture failed")
                    throw error
                }
            }
        } catch {
            await connection.close(reason: "batched frame fixture teardown")
            throw error
        }
        await connection.close(reason: "batched frame fixture teardown")
        return recordedMethods
    }

    private func recordAndClose(_ method: String) async {
        recordedMethods.append(method)
        firstRecorded.continuation.finish()
        for await _ in firstMayClose.stream {}
        await session?.close(reason: "test close after first batched frame")
        secondMayReturn.continuation.finish()
    }

    private func releaseSignals() {
        firstRecorded.continuation.finish()
        secondAuthorizeStarted.continuation.finish()
        firstMayClose.continuation.finish()
        secondMayReturn.continuation.finish()
    }

    private static func waitForSignal(_ signal: AsyncStream<Void>, phase: SignalPhase) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in signal {}
                try Task.checkCancellation()
            }
            group.addTask {
                // Preserve the original one-second failure deadline; never settle or poll.
                try await ContinuousClock().sleep(for: .seconds(1))
                throw Failure.timedOut(phase)
            }
            _ = try await group.next()
        }
    }
}
