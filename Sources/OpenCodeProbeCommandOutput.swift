import BmuxFoundation
import Darwin
import Foundation

/// Captures one version probe's merged output, joining its process and sole reader.
struct OpenCodeProbeCommandOutput: Sendable {
    let executable: String
    let arguments: [String]
    let environment: [String: String]
    let workingDirectory: URL?
    let timeout: Duration
    let terminationGrace: Duration

    func run() async -> String? {
        guard !Task.isCancelled else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.environment = environment
        process.currentDirectoryURL = workingDirectory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let completion = OpenCodeProbeCompletion()
        let exit = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingOldest(1))
        process.terminationHandler = { _ in
            completion.recordExit()
            exit.continuation.yield(())
            exit.continuation.finish()
        }
        // This waiter is independent of parent cancellation so cleanup still joins exit.
        let exitWaiter = Task {
            var iterator = exit.stream.makeAsyncIterator()
            _ = await iterator.next()
        }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        // Blocking pipe I/O belongs on a retained detached task, joined before closing its fd.
        let reader = Task.detached {
            FileHandle(fileDescriptor: descriptor, closeOnDealloc: false).readDataToEndOfFileOrEmpty()
        }
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let timer = Task {
            do {
                // Injected process deadline; cancelled and joined on every completion path.
                try await ContinuousClock().sleep(until: deadline)
                completion.recordDeadline()
            } catch is CancellationError {
                return
            } catch {
                completion.recordDeadline()
            }
        }
        defer {
            process.terminationHandler = nil
            exit.continuation.finish()
            pipe.fileHandleForReading.closeFile()
        }
        do {
            try Task.checkCancellation()
            try process.run()
        } catch {
            // An unavailable optional probe remains an unsupported result, after owned cleanup.
            pipe.fileHandleForWriting.closeFile()
            timer.cancel()
            await timer.value
            exit.continuation.finish()
            await exitWaiter.value
            _ = await reader.value
            return nil
        }
        pipe.fileHandleForWriting.closeFile()
        var iterator = completion.results.makeAsyncIterator()
        let first = await iterator.next()
        timer.cancel()
        await timer.value
        let completedInTime: Bool
        if case .exited(let arrival) = first {
            completedInTime = arrival <= deadline
        } else {
            completedInTime = false
        }
        if !completedInTime || Task.isCancelled {
            if process.isRunning {
                process.terminate()
            }
            let terminationDeadline = ContinuousClock.now.advanced(by: terminationGrace)
            let escalation = Task {
                do {
                    // Injected termination grace; cancelled and joined once native exit arrives.
                    try await ContinuousClock().sleep(until: terminationDeadline)
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
            await exitWaiter.value
            escalation.cancel()
            await escalation.value
        } else {
            await exitWaiter.value
        }
        // As before, a descendant retaining this pipe can delay EOF after the direct child exits.
        // There is exactly one reader, so exit cannot overtake an in-flight buffer append.
        let output = await reader.value
        guard completedInTime, !Task.isCancelled else { return nil }
        return String(data: output, encoding: .utf8)
    }
}
