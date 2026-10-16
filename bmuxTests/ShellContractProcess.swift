import Darwin
import Foundation

/// Joins the owned shell process before its contract fixture releases files or sockets.
struct ShellContractProcess {
    let root: URL
    let deadline: Duration
    let terminationGrace: Duration

    init(root: URL, deadline: Duration = .seconds(5), terminationGrace: Duration = .milliseconds(200)) {
        self.root = root
        self.deadline = deadline
        self.terminationGrace = terminationGrace
    }

    enum Failure: Error { case timedOut }

    func run(executable: String, arguments: [String], environment: [String: String]) async throws -> Result {
        try Task.checkCancellation()
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        try Data().write(to: stdout)
        try Data().write(to: stderr)
        let output = try FileHandle(forWritingTo: stdout)
        defer { try? output.close() }
        let errors = try FileHandle(forWritingTo: stderr)
        defer { try? errors.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = root
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = errors
        let completion = ShellContractProcessCompletion()
        let (events, signal) = AsyncStream<Int32>.makeStream()
        process.terminationHandler = { ended in
            completion.record(status: ended.terminationStatus)
            signal.yield(ended.terminationStatus)
            signal.finish()
        }
        defer { process.terminationHandler = nil }
        do { try process.run() } catch {
            signal.finish()
            throw error
        }
        let end = ContinuousClock.now.advanced(by: deadline)
        // This retained consumer joins native exit; its scheduling never decides timeliness.
        let exit = Task { () -> Int32 in
            for await status in events { return status }
            return process.terminationStatus
        }
        let status: Int32
        do {
            status = try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    defer { group.cancelAll() }
                    group.addTask {
                        do {
                            // Original injected process failure deadline, never a settling delay.
                            try await ContinuousClock().sleep(until: end)
                            completion.fail(Failure.timedOut)
                        } catch is CancellationError {
                            return
                        } catch { completion.fail(error) }
                    }
                    for await outcome in completion.results {
                        let receipt = try outcome.get()
                        guard receipt.observedAt <= end else { throw Failure.timedOut }
                        return receipt.status
                    }
                    throw CancellationError()
                }
            } onCancel: {
                completion.fail(CancellationError())
            }
        } catch {
            let originalError = error
            let terminationStartedAt = ContinuousClock.now
            if process.isRunning { process.terminate() }
            let grace = Task {
                // Preserve the injected owned-process SIGTERM grace period before escalation.
                do { try await ContinuousClock().sleep(until: terminationStartedAt.advanced(by: terminationGrace)) }
                catch { return }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            _ = await exit.value
            grace.cancel()
            await grace.value
            try Task.checkCancellation()
            throw originalError
        }
        _ = await exit.value
        try Task.checkCancellation()
        return Result(
            status: status, terminatedNormally: process.terminationReason == .exit,
            stdout: try String(contentsOf: stdout, encoding: .utf8),
            stderr: try String(contentsOf: stderr, encoding: .utf8)
        )
    }
}
