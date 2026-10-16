import Darwin
import Foundation
import Testing

@Suite("CLI hook no-response telemetry", .serialized)
struct CLIHookNoResponseTests {
    final class BundleProbe {}

    struct ProcessRunResult {
        let status: Int32
        let stdout: String
        let stderr: String
        let timedOut: Bool
    }

    struct MockSocketServer {
        let handled: DispatchSemaphore

        func wait(timeout: TimeInterval) -> Bool {
            handled.wait(timeout: .now() + timeout) == .success
        }
    }

    @Test func genericLifecycleFeedTelemetryDoesNotWaitForSocketResponse() async throws {
        let fixture = try GenericLifecycleFeedNoResponseFixture(cli: Self.bundledCLIPath())
        // A timeout throws only after the producer and socket ownership have joined.
        let result = try await fixture.run()
        #expect(result.observed, "socket server did not observe lifecycle feed.push")
        #expect(result.output.terminatedNormally, Comment(rawValue: result.output.stderr))
        #expect(result.output.status == 0, Comment(rawValue: result.output.stderr))
        #expect(result.output.stdout == "{}\n")
        #expect(
            result.commands.contains { $0.contains(#""method":"feed.push""#) },
            "Expected lifecycle hook to still emit Feed telemetry"
        )
    }

    @Test func nonActionableFeedHookDoesNotBlockWhenAcceptedSocketStopsReading() throws {
        let cliPath = try Self.bundledCLIPath()
        let socketPath = Self.makeSocketPath("feed-no-read")
        let listenerFD = try Self.bindUnixSocket(at: socketPath, backlog: 1)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-feed-no-read-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }

        let server = Self.startAcceptedSocketThatDoesNotRead(listenerFD: listenerFD, holdFor: 1.0)
        let largeToolInput = String(repeating: "x", count: 8 * 1024 * 1024)
        let input = """
        {"hook_event_name":"PreToolUse","session_id":"gemini-session-no-read","cwd":"\(root.path)","tool_name":"read","tool_input":{"payload":"\(largeToolInput)"}}
        """

        let result = Self.runProcess(
            executablePath: cliPath,
            arguments: [
                "--socket", socketPath,
                "hooks", "feed",
                "--source", "gemini",
                "--event", "PreToolUse",
            ],
            environment: [
                "HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PWD": root.path,
                "BMUX_SOCKET_PATH": socketPath,
                "BMUX_WORKSPACE_ID": "33333333-3333-3333-3333-333333333333",
                "BMUX_SURFACE_ID": "44444444-4444-4444-4444-444444444444",
                "BMUX_GEMINI_PID": "626262",
                "BMUX_CLI_SENTRY_DISABLED": "1",
            ],
            standardInput: input,
            timeout: 3
        )

        #expect(
            server.wait(timeout: 5),
            "socket server did not accept feed.push connection; status=\(result.status) timedOut=\(result.timedOut) stdout=\(result.stdout) stderr=\(result.stderr)"
        )
        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(result.stdout == "{}\n")
    }

    private static func bundledCLIPath() throws -> String {
        let fileManager = FileManager.default
        let appBundleURL = Bundle(for: BundleProbe.self)
            .bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let enumerator = fileManager.enumerator(
            at: appBundleURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        while let item = enumerator?.nextObject() as? URL {
            guard item.lastPathComponent == "bmux",
                  item.path.contains(".app/Contents/Resources/bin/bmux") else {
                continue
            }
            return item.path
        }

        throw NSError(domain: "bmux.tests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Bundled bmux CLI not found in \(appBundleURL.path)",
        ])
    }

    private static func makeSocketPath(_ name: String) -> String {
        let shortID = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        return URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("cli-\(name.prefix(6))-\(shortID).sock")
            .path
    }

    private static func bindUnixSocket(at path: String, backlog: Int32) throws -> Int32 {
        unlink(path)
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw posixError("failed to create Unix socket")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout.size(ofValue: addr.sun_path)
        let utf8 = Array(path.utf8)
        guard utf8.count < maxPathLength else {
            Darwin.close(fd)
            throw NSError(domain: "bmux.tests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "socket path too long: \(path)",
            ])
        }
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { buffer in
                for index in 0..<utf8.count {
                    buffer[index] = CChar(bitPattern: utf8[index])
                }
                buffer[utf8.count] = 0
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(fd)
            throw posixError("failed to bind Unix socket")
        }
        guard Darwin.listen(fd, backlog) == 0 else {
            Darwin.close(fd)
            throw posixError("failed to listen on Unix socket")
        }
        return fd
    }

    private static func startAcceptedSocketThatDoesNotRead(listenerFD: Int32, holdFor: TimeInterval) -> MockSocketServer {
        let handled = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.accept(listenerFD, sockaddrPtr, &clientAddrLen)
                }
            }
            guard clientFD >= 0 else {
                handled.signal()
                return
            }
            handled.signal()
            _ = DispatchSemaphore(value: 0).wait(timeout: .now() + holdFor)
            Darwin.close(clientFD)
        }
        return MockSocketServer(handled: handled)
    }

    private static func runProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        standardInput: String? = nil,
        timeout: TimeInterval
    ) -> ProcessRunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let stdinHandle: FileHandle?
        let stdinURL: URL?
        if let standardInput {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-test-stdin-\(UUID().uuidString).json")
            do {
                try Data(standardInput.utf8).write(to: url)
                let handle = try FileHandle(forReadingFrom: url)
                process.standardInput = handle
                stdinHandle = handle
                stdinURL = url
            } catch {
                try? FileManager.default.removeItem(at: url)
                return ProcessRunResult(status: -1, stdout: "", stderr: "\(error)", timedOut: false)
            }
        } else {
            stdinHandle = nil
            stdinURL = nil
        }
        defer {
            try? stdinHandle?.close()
            if let stdinURL {
                try? FileManager.default.removeItem(at: stdinURL)
            }
        }

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }

        do {
            try process.run()
        } catch {
            return ProcessRunResult(status: -1, stdout: "", stderr: "\(error)", timedOut: false)
        }

        let timedOut = finished.wait(timeout: .now() + timeout) != .success
        if timedOut {
            process.terminate()
            _ = finished.wait(timeout: .now() + 1)
        }

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        return ProcessRunResult(
            status: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
    }

    private static func posixError(_ message: String) -> NSError {
        NSError(domain: "bmux.tests", code: Int(errno), userInfo: [
            NSLocalizedDescriptionKey: "\(message): errno \(errno)",
        ])
    }
}
