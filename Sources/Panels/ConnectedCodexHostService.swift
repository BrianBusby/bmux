import BmuxAgentChat
import BmuxFoundation
import Foundation

/// Owns new shared provider processes independently of all presentation views.
/// Existing ordinary CLI processes are never adopted or replaced.
actor ConnectedCodexHostService: ConnectedCodexHosting {
    private let executable: URL
    private let root: URL
    private let environment: [String: String]
    private var processes: [UUID: Process] = [:]

    init(executable: URL, root: URL, environment: [String: String]) {
        self.executable = executable
        self.root = root
        self.environment = environment
    }

    func launch(surfaceID: UUID, workingDirectory: String) async throws -> ConnectedCodexHost {
        let version = await CommandRunner(environment: environment).runStandardOutput(
            directory: workingDirectory, executable: executable.path, arguments: ["--version"], timeout: 5
        )
        // Capabilities are empirical and version-specific; fail closed on upgrades.
        guard version?.trimmingCharacters(in: .whitespacesAndNewlines) == "codex-cli 0.154.0" else {
            throw CodexControlError.unsupported
        }
        let directory = root.appendingPathComponent(surfaceID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let token = UUID().uuidString + UUID().uuidString
        let tokenURL = directory.appendingPathComponent("connection-token")
        guard FileManager.default.createFile(atPath: tokenURL.path, contents: Data(token.utf8), attributes: [.posixPermissions: 0o600]) else {
            throw CodexControlError.disconnected
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "ws://127.0.0.1:0", "--ws-auth", "capability-token", "--ws-token-file", tokenURL.path]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.environment = environment.filter { !$0.key.hasPrefix("BMUX") && !$0.key.hasPrefix("CMUX") && $0.key != "CODEX_THREAD_ID" }
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.standardInput = FileHandle.nullDevice
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(16))
        // FileHandle's legacy callback is confined to this async process-I/O seam.
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { continuation.finish() } else { continuation.yield(data) }
        }
        process.terminationHandler = { _ in continuation.finish() }
        // Genuine startup deadline, canceled immediately after readiness or failure.
        let deadline = Task {
            do { try await ContinuousClock().sleep(for: .seconds(15)) } catch { return }
            continuation.finish()
        }
        defer { deadline.cancel() }
        do {
            try process.run()
            processes[surfaceID] = process
            var buffer = ""
            var endpoint: URL?
            for await bytes in stream {
                buffer += String(decoding: bytes, as: UTF8.self)
                guard buffer.utf8.count < 16_384 else { break }
                if let line = buffer.components(separatedBy: "\n").dropLast().first(where: { $0.contains("listening on: ws://127.0.0.1:") }),
                   let address = line.components(separatedBy: "listening on: ").last {
                    endpoint = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines))
                    break
                }
            }
            // Drain future diagnostics without retaining or logging provider output.
            output.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
            guard let endpoint, process.isRunning else { throw CodexControlError.disconnected }
            try await verifyAuthenticationRequired(endpoint)
            let connection = CodexRPCConnection(transport: try CodexLoopbackWebSocket(endpoint: endpoint, token: token))
            try await connection.start()
            // The credential never appears in argv or a renderer bridge payload.
            let shellCommand = "BMUX_CONNECTED_CODEX_TOKEN=$(cat \(Self.quote(tokenURL.path))) exec \(Self.quote(executable.path)) --remote \(Self.quote(endpoint.absoluteString)) --remote-auth-token-env BMUX_CONNECTED_CODEX_TOKEN"
            let command = "/bin/sh -c " + Self.quote(shellCommand)
            return ConnectedCodexHost(surfaceID: surfaceID, threadID: nil, processID: process.processIdentifier,
                                      endpoint: endpoint, terminalCommand: command, connection: connection,
                                      control: nil)
        } catch {
            if process.isRunning { process.terminate() }
            processes.removeValue(forKey: surfaceID)
            output.fileHandleForReading.readabilityHandler = nil
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    /// The dedicated host has exactly one original TUI. Never select by cwd,
    /// PID, recency, or a first element when additional loaded threads exist.
    func adoptOriginalThread(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost {
        guard host.threadID == nil else { return host }
        let data = try await host.connection.request(method: "thread/loaded/list", params: Data("{}".utf8))
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = response["data"] as? [String], ids.count == 1,
              response["nextCursor"] is NSNull else { throw CodexControlError.wrongThread }
        var adopted = host
        adopted.threadID = ids[0]
        adopted.control = CodexSharedControl(threadID: ids[0], connection: host.connection)
        return adopted
    }

    func reconnect(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost {
        guard let process = processes[host.surfaceID], process.isRunning,
              process.processIdentifier == host.processID else { throw CodexControlError.disconnected }
        let tokenURL = root.appendingPathComponent(host.surfaceID.uuidString).appendingPathComponent("connection-token")
        let token = try String(contentsOf: tokenURL, encoding: .utf8)
        let connection = CodexRPCConnection(transport: try CodexLoopbackWebSocket(endpoint: host.endpoint, token: token))
        do {
            try await connection.start()
            let loaded = try await connection.request(method: "thread/loaded/list", params: Data("{}".utf8))
            guard let threadID = host.threadID,
                  let response = try JSONSerialization.jsonObject(with: loaded) as? [String: Any],
                  (response["data"] as? [String])?.contains(threadID) == true else { throw CodexControlError.wrongThread }
            await host.control?.reconnect(using: connection)
            try await host.control?.reconcile()
            var replacement = host
            replacement.connection = connection
            return replacement
        } catch {
            await connection.disconnect()
            throw error
        }
    }

    /// Explicit owning-terminal close or rollback before a terminal is delivered.
    func endOwnedHost(surfaceID: UUID) {
        if let process = processes.removeValue(forKey: surfaceID), process.isRunning { process.terminate() }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(surfaceID.uuidString))
    }

    private func verifyAuthenticationRequired(_ endpoint: URL) async throws {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.scheme = "http"
        var request = URLRequest(url: components.url!, timeoutInterval: 5)
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue(Data(UUID().uuidString.prefix(16).utf8).base64EncodedString(), forHTTPHeaderField: "Sec-WebSocket-Key")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 401 else { throw CodexControlError.unsupported }
    }

    private static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
