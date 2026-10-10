import BmuxAgentChat
import BmuxFoundation
import Foundation

/// Owns new shared provider processes independently of all presentation views.
/// Existing ordinary CLI processes are never adopted or replaced.
actor ConnectedCodexHostService: ConnectedCodexHosting {
    private let resolveExecutable: @Sendable (String, [String: String]) async throws -> AgentSessionLaunchPlan
    private let hookWrapper: URL?
    private let root: URL
    private let environment: [String: String]
    private let connect: @Sendable (URL, String) async throws -> CodexRPCConnection
    private var processes: [UUID: Process] = [:]

    init(resolveExecutable: @escaping @Sendable (String, [String: String]) async throws -> AgentSessionLaunchPlan,
         root: URL, environment: [String: String], hookWrapper: URL? = nil,
         connect: @escaping @Sendable (URL, String) async throws -> CodexRPCConnection = { endpoint, token in
             try await ConnectedCodexHostService.authenticatedConnection(endpoint, token: token)
         }) {
        self.resolveExecutable = resolveExecutable
        self.hookWrapper = hookWrapper
        self.root = root
        self.environment = environment
        self.connect = connect
    }

    func launch(workspaceID: UUID, surfaceID: UUID, workingDirectory: String, configuration: ConnectedCodexLaunchConfiguration = .init()) async throws -> ConnectedCodexHost {
        let configuredEnvironment = environment.merging(configuration.environment) { _, configured in configured }
        let plan = try await resolveExecutable(workingDirectory, configuredEnvironment)
        try Task.checkCancellation()
        let executable = plan.executableURL
        let launchEnvironment = plan.environment
        let version = await CommandRunner(environment: launchEnvironment).runStandardOutput(
            directory: workingDirectory, executable: executable.path, arguments: ["--version"], timeout: 5
        )
        // The pin is promoted only after shared-control compatibility is verified.
        guard let version = version?.trimmingCharacters(in: .whitespacesAndNewlines),
              version == "codex-cli " + ManagedCodexRelease.validated.version else {
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
        process.executableURL = hookWrapper ?? executable
        process.arguments = ["app-server", "--listen", "ws://127.0.0.1:0", "--ws-auth", "capability-token", "--ws-token-file", tokenURL.path] + configuration.hostArguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        // Discard inherited agent identity, then route hooks only to this host's owner.
        // App-supplied routing wins over configured workspace environment values.
        var hostEnvironment = launchEnvironment.filter { !$0.key.hasPrefix("BMUX") && !$0.key.hasPrefix("CMUX") && $0.key != "CODEX_THREAD_ID" }
        for key in ["BMUX_SOCKET_PATH", "BMUX_BUNDLED_CLI_PATH", "BMUX_BUNDLE_ID"] {
            hostEnvironment[key] = environment[key]
        }
        hostEnvironment["BMUX_WORKSPACE_ID"] = workspaceID.uuidString
        hostEnvironment["BMUX_SURFACE_ID"] = surfaceID.uuidString
        hostEnvironment["BMUX_CUSTOM_CODEX_PATH"] = executable.path
        hostEnvironment["BMUX_CODEX_CONNECTED_HOST"] = "1"
        // Persist the original interactive launch, never the ephemeral host endpoint.
        let resumeArguments = ([executable.path] + configuration.arguments).joined(separator: "\0") + "\0"
        hostEnvironment["BMUX_AGENT_LAUNCH_ARGV_B64"] = Data(resumeArguments.utf8).base64EncodedString()
        hostEnvironment["BMUX_CODEX_HOOKS_DISABLED"] = launchEnvironment["BMUX_CODEX_HOOKS_DISABLED"]
        process.environment = hostEnvironment
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
        var connection: CodexRPCConnection?
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
            let authenticated = try await connect(endpoint, token)
            connection = authenticated
            let overrides = (["-c", "check_for_update_on_startup=false"] + configuration.arguments + (try await compatibleModelArguments(using: authenticated, workingDirectory: workingDirectory, configuration: configuration)))
                .map(Self.quote).joined(separator: " ")
            guard !Task.isCancelled, process.isRunning, processes[surfaceID] === process else {
                throw CodexControlError.disconnected
            }
            // The credential never appears in argv or a renderer bridge payload.
            // GUI environments may lack the shebang runtime (e.g. node for a Bun install).
            // The original TUI must use the same resolved PATH as its shared host.
            let pathSetup = launchEnvironment["PATH"].map { "export PATH=\(Self.quote($0)); " } ?? ""
            let shellCommand = pathSetup + "BMUX_CONNECTED_CODEX_TOKEN=$(cat \(Self.quote(tokenURL.path))) exec \(Self.quote(executable.path)) --remote \(Self.quote(endpoint.absoluteString)) --remote-auth-token-env BMUX_CONNECTED_CODEX_TOKEN"
                + (overrides.isEmpty ? "" : " " + overrides)
            let command = "/bin/sh -c " + Self.quote(shellCommand)
            return ConnectedCodexHost(providerVersion: String(version.dropFirst("codex-cli ".count)), surfaceID: surfaceID, threadID: nil, processID: process.processIdentifier,
                                      endpoint: endpoint, terminalCommand: command, connection: authenticated,
                                      control: nil)
        } catch {
            await connection?.disconnect()
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

    /// Compatibility overrides belong only to this new TUI. Saved configuration
    /// and already-running threads retain their original model selection.
    private func compatibleModelArguments(using connection: CodexRPCConnection, workingDirectory: String, configuration: ConnectedCodexLaunchConfiguration) async throws -> [String] {
        guard !configuration.hasExplicitModel else { return [] }
        let decoder = JSONDecoder()
        let account = try decoder.decode(AccountResponse.self, from: await connection.request(
            method: "account/read", params: Data(#"{"refreshToken":false}"#.utf8)))
        guard account.account?.type == "chatgpt" else { return [] }
        let configParams = try JSONSerialization.data(withJSONObject: [
            "includeLayers": false, "cwd": workingDirectory])
        let config = try decoder.decode(ConfigResponse.self, from: await connection.request(method: "config/read", params: configParams)).config
        guard config.model_provider == nil || config.model_provider == "openai" else { return [] }
        var models: [CatalogModel] = []
        var cursor: String?
        var seenCursors: Set<String> = []
        var complete = false
        // The client catalog is finite; malformed/repeated pagination fails closed.
        for _ in 0..<8 {
            var params: [String: Any] = ["limit": 100, "includeHidden": true]
            if let cursor { params["cursor"] = cursor }
            let page = try decoder.decode(ModelPage.self, from: await connection.request(
                method: "model/list", params: JSONSerialization.data(withJSONObject: params)))
            models.append(contentsOf: page.data)
            if let model = config.model, models.contains(where: { $0.model == model }) { return [] }
            guard let next = page.nextCursor else { complete = true; break }
            guard seenCursors.insert(next).inserted else { throw CodexControlError.invalidResponse }
            cursor = next
        }
        let defaults = models.filter { $0.isDefault && !$0.hidden && !$0.model.isEmpty }
        guard complete, defaults.count == 1, let selected = defaults.first else { throw CodexControlError.invalidResponse }
        var arguments = ["--model", selected.model]
        if let effort = config.model_reasoning_effort,
           !selected.supportedReasoningEfforts.contains(where: { $0.reasoningEffort == effort }) {
            guard selected.supportedReasoningEfforts.contains(where: { $0.reasoningEffort == selected.defaultReasoningEffort }) else {
                throw CodexControlError.invalidResponse
            }
            let value = String(decoding: try JSONEncoder().encode(selected.defaultReasoningEffort), as: UTF8.self)
            arguments += ["-c", "model_reasoning_effort=" + value]
        }
        return arguments
    }

    private struct AccountResponse: Decodable { let account: Account? }
    private struct Account: Decodable { let type: String }
    private struct ConfigResponse: Decodable { let config: ModelConfig }
    private struct ModelConfig: Decodable {
        let model: String?
        let model_provider: String?
        let model_reasoning_effort: String?
    }
    private struct ModelPage: Decodable { let data: [CatalogModel]; let nextCursor: String? }
    private struct CatalogModel: Decodable {
        let model: String
        let hidden: Bool
        let isDefault: Bool
        let defaultReasoningEffort: String
        let supportedReasoningEfforts: [ReasoningOption]
    }
    private struct ReasoningOption: Decodable { let reasoningEffort: String }

    private static func authenticatedConnection(_ endpoint: URL, token: String) async throws -> CodexRPCConnection {
        try await verifyAuthenticationRequired(endpoint)
        let connection = CodexRPCConnection(transport: try CodexLoopbackWebSocket(endpoint: endpoint, token: token))
        try await connection.start()
        return connection
    }

    private static func verifyAuthenticationRequired(_ endpoint: URL) async throws {
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
