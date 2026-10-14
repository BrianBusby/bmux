import Darwin
import Foundation

/// Joins the owned shell process before its contract fixture releases files or sockets.
struct ShellContractProcess {
    let root: URL

    struct Result: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
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
        let (events, signal) = AsyncStream<Int32>.makeStream()
        process.terminationHandler = { ended in
            signal.yield(ended.terminationStatus)
            signal.finish()
        }
        do { try process.run() } catch {
            signal.finish()
            throw error
        }
        // This retained consumer is joined on success, failure and cancellation.
        let exit = Task { () -> Int32 in
            for await status in events { return status }
            return process.terminationStatus
        }
        let status = try await withThrowingTaskGroup(of: Int32.self) { group in
            defer { group.cancelAll() }
            group.addTask { await exit.value }
            group.addTask {
                // Original interactive-shell failure deadline, never a settling delay.
                try await ContinuousClock().sleep(for: .seconds(5))
                throw Failure.timedOut
            }
            do {
                guard let status = try await group.next() else { throw CancellationError() }
                return status
            } catch {
                // Escalation happens inside the group, before its exit waiter can be joined.
                if process.isRunning { process.terminate() }
                let grace = Task {
                    // Match CommandRunner's genuine owned-process SIGTERM grace period.
                    do { try await ContinuousClock().sleep(for: .milliseconds(200)) }
                    catch { return }
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
                _ = await exit.value
                grace.cancel()
                await grace.value
                throw error
            }
        }
        return Result(status: status, stdout: try String(contentsOf: stdout, encoding: .utf8), stderr: try String(contentsOf: stderr, encoding: .utf8))
    }
}
