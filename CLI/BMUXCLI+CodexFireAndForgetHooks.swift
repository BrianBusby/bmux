import BmuxAgentChat
import BmuxSettings
import Darwin
import Foundation

extension BMUXCLI {
    /// The per-invocation Codex hook events the wrapper injects, paired with the
    /// bmux subcommand they call and the codex hook timeout (ms). Lifecycle
    /// events are short; feed events (`PreToolUse`/`PermissionRequest`) are long
    /// because the user may take time to approve. This is the single source of
    /// truth for `bmux-codex-wrapper`'s injection, mirrored from the historic
    /// hand-rolled `bmux_codex_add_hook` calls in the wrapper.
    static let codexWrapperInjectionEvents: [(agentEvent: String, bmuxSubcommand: String, timeoutMs: Int)] = [
        ("SessionStart", "session-start", 10000),
        ("UserPromptSubmit", "prompt-submit", 10000),
        ("Stop", "stop", 10000),
        ("PreToolUse", "pre-tool-use", 120000),
        ("PostToolUse", "post-tool-use", 10000),
        ("PermissionRequest", "notification", 120000),
    ]

    /// Emit, NUL-separated to stdout, the exact codex arg list the wrapper must
    /// splice ahead of the user's args to enable + inject bmux's fire-and-forget
    /// hooks for one codex invocation. Returns the arg list:
    ///   --enable\0hooks\0--dangerously-bypass-hook-trust\0
    ///   -c\0hooks.SessionStart=[{hooks=[{type="command",command='''<ff>''',timeout=10000}]}]\0
    ///   -c\0hooks.UserPromptSubmit=...\0 ... (one `-c` pair per event)
    /// where `<ff>` is `codexFireAndForgetAgentHookShellCommand(...)` so each
    /// hook returns `{}` to codex instantly and backgrounds the real bmux call.
    /// Requires no live socket: pure string construction from the agent def.
    func emitCodexWrapperInjectArgs() throws {
        guard let codexDef = Self.agentDef(named: "codex") else {
            throw CLIError(message: "Codex hook integration is unavailable.")
        }
        // Prefer a #!/bin/sh SCRIPT FILE as the hook command over an inline shell
        // snippet. Some codex-compatible runtimes (subrouters, proxies) exec the
        // `command` string directly as a program instead of via a shell, so an
        // inline snippet fails with "No such file or directory (os error 2)". A
        // bare executable file path runs correctly whether the runtime execs it
        // directly or through a shell, and normal codex (which runs it via shell)
        // is unaffected. The scripts are env-driven and identical across
        // invocations, so they are written once into a bmux-owned dir (~/.bmux/
        // hooks), not the user's ~/.codex. Any write failure falls back to the
        // inline snippet so the working path can never regress.
        let hooksDir = Self.codexHookScriptsDirectory()
        var args: [String] = ["--enable", "hooks", "--dangerously-bypass-hook-trust"]
        for event in Self.codexWrapperInjectionEvents {
            let groups = try Self.codexWrapperHookGroups(
                for: event,
                codexDef: codexDef,
                hooksDir: hooksDir
            )
            let toml = "hooks.\(event.agentEvent)=\(groups)"
            args.append("-c")
            args.append(toml)
        }
        // NUL-TERMINATE each arg (trailing NUL after the last too) so a bash
        // `while IFS= read -r -d '' arg` loop captures every element including
        // the final one — a separator-only stream drops the unterminated last
        // arg at EOF.
        var out = Data()
        for arg in args {
            out.append(Data(arg.utf8))
            out.append(0)
        }
        FileHandle.standardOutput.write(out)
    }

    private static func codexWrapperHookGroups(
        for event: (agentEvent: String, bmuxSubcommand: String, timeoutMs: Int),
        codexDef: AgentHookDef,
        hooksDir: URL?
    ) throws -> String {
        var hookGroups: [String] = []
        if event.agentEvent == "PreToolUse" {
            let optimizerCommand = codexOptimizerHookCommandString(for: codexDef)
            hookGroups.append(try codexWrapperHookGroupTOML(command: optimizerCommand, timeoutMs: 5_000))
        }

        let ff = Self.codexFireAndForgetAgentHookShellCommand(
            "bmux hooks codex \(event.bmuxSubcommand)", for: codexDef
        )
        let command: String
        if let scriptPath = hooksDir.flatMap({
            Self.writeCodexHookScript(subcommand: event.bmuxSubcommand, body: ff, in: $0)
        }), !scriptPath.contains("'''") {
            command = scriptPath
        } else {
            command = ff
        }
        hookGroups.append(try codexWrapperHookGroupTOML(command: command, timeoutMs: event.timeoutMs))
        return "[\(hookGroups.joined(separator: ","))]"
    }

    private static func codexWrapperHookGroupTOML(command: String, timeoutMs: Int) throws -> String {
        // TOML multi-line literal string ('''...''') preserves bytes verbatim
        // and may contain single quotes, so the embedded `echo '{}'` / `sh -c
        // '...'` survive with no escaping. TOML forbids only a literal triple
        // single quote inside; guard against it (neither a path nor the command
        // ever has one).
        guard !command.contains("'''") else {
            throw CLIError(message: "Codex hook command contains a triple single quote and cannot be TOML-encoded.")
        }
        return "{hooks=[{type=\"command\",command='''\(command)''',timeout=\(timeoutMs)}]}"
    }

    /// The bmux-owned directory holding the generated codex hook scripts.
    /// `~/.bmux/hooks` (NOT the user's `~/.codex`), created on demand. Returns
    /// nil if it cannot be created, so the caller falls back to inline commands.
    static func codexHookScriptsDirectory() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home
            .appendingPathComponent(".bmux", isDirectory: true)
            .appendingPathComponent("hooks", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    /// Writes (idempotently) a `#!/bin/sh` hook script for one event into `dir`
    /// and returns its absolute path, or nil on any failure. The body is the
    /// same env-driven fire-and-forget snippet used inline; as a real executable
    /// file it runs under any runtime, including ones that exec the hook command
    /// directly rather than through a shell. Content is identical across
    /// invocations, so the file is only rewritten when missing or changed.
    static func writeCodexHookScript(subcommand: String, body: String, in dir: URL) -> String? {
        let safeName = subcommand.replacingOccurrences(
            of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression
        )
        let url = dir.appendingPathComponent("bmux-codex-hook-\(safeName).sh", isDirectory: false)
        let contents = "#!/bin/sh\n\(body)\n"
        let fileManager = FileManager.default
        if let existing = try? String(contentsOf: url, encoding: .utf8), existing == contents {
            // Ensure it stays executable, then reuse.
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            return url.path
        }
        do {
            try contents.data(using: .utf8)?.write(to: url, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            return url.path
        } catch {
            return nil
        }
    }

    func runCodexOptimizePreToolUseHook() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["BMUX_SURFACE_ID"]?.isEmpty == false,
              env["BMUX_CODEX_HOOKS_DISABLED"] != "1",
              Self.currentAgentTokenOptimizationMode() != .off
        else {
            print("{}")
            return
        }

        let stdinData = FileHandle.standardInput.readDataToEndOfFile()
        guard !stdinData.isEmpty,
              let payload = try? JSONSerialization.jsonObject(with: stdinData) as? [String: Any]
        else {
            print("{}")
            return
        }

        let eventName = Self.agentHookString(in: payload, keys: ["hook_event_name", "event"]) ?? ""
        guard eventName == "PreToolUse" else {
            print("{}")
            return
        }

        guard var updatedInput = Self.agentHookToolInputDictionary(from: payload),
              let commandKey = Self.agentHookCommandKey(in: updatedInput),
              let command = updatedInput[commandKey] as? String,
              Self.agentHookCommandEligibleForTokenProxy(command)
        else {
            print("{}")
            return
        }

        let cwd = Self.agentHookString(in: payload, keys: ["cwd"])
            ?? Self.agentHookString(in: updatedInput, keys: ["cwd", "workdir", "working_directory"])
        updatedInput[commandKey] = Self.agentTokenProxyShellCommand(command: command, cwd: cwd)

        try Self.writeAgentHookJSONObject([
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "updatedInput": updatedInput,
            ] as [String: Any],
            "decision": "approve",
        ] as [String: Any])
    }

    func runClaudeOptimizePreToolUseHook() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["BMUX_SURFACE_ID"]?.isEmpty == false,
              env["BMUX_CLAUDE_HOOKS_DISABLED"] != "1",
              Self.currentAgentTokenOptimizationMode() != .off
        else {
            print("{}")
            return
        }

        let stdinData = FileHandle.standardInput.readDataToEndOfFile()
        guard !stdinData.isEmpty,
              let payload = try? JSONSerialization.jsonObject(with: stdinData) as? [String: Any]
        else {
            print("{}")
            return
        }

        let eventName = Self.agentHookString(in: payload, keys: ["hook_event_name", "event"]) ?? ""
        let toolName = Self.agentHookString(in: payload, keys: ["tool_name", "toolName"]) ?? ""
        guard eventName == "PreToolUse", toolName == "Bash" else {
            print("{}")
            return
        }

        guard var updatedInput = Self.agentHookToolInputDictionary(from: payload),
              let commandKey = Self.agentHookCommandKey(in: updatedInput),
              let command = updatedInput[commandKey] as? String,
              Self.agentHookCommandEligibleForTokenProxy(command)
        else {
            print("{}")
            return
        }

        let cwd = Self.agentHookString(in: payload, keys: ["cwd"])
            ?? Self.agentHookString(in: updatedInput, keys: ["cwd", "workdir", "working_directory"])
        updatedInput[commandKey] = Self.agentTokenProxyShellCommand(command: command, cwd: cwd)

        try Self.writeAgentHookJSONObject([
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "updatedInput": updatedInput,
            ] as [String: Any],
            "decision": "approve",
        ] as [String: Any])
    }

    func runAgentTokenProxy(commandArgs: [String]) throws {
        guard let commandHex = optionValue(commandArgs, name: "--command-hex"),
              let command = Self.stringFromLowercaseHex(commandHex)
        else {
            throw CLIError(message: String(
                localized: "cli.error.agentTokenProxyRequiresCommandHex",
                defaultValue: "agent-token-proxy requires --command-hex <hex>"
            ))
        }
        let cwd = optionValue(commandArgs, name: "--cwd-hex")
            .flatMap(Self.stringFromLowercaseHex)
            .flatMap { value -> String? in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

        let result = CLIProcessRunner.runProcess(
            executablePath: Self.agentTokenProxyShellPath(),
            arguments: ["-lc", command],
            currentDirectoryPath: cwd
        )

        let mode = Self.currentAgentTokenOptimizationMode()
        guard mode != .off else {
            Self.writeAgentTokenProxyRawResult(result)
            Darwin.exit(result.status)
        }

        let optimizationInput = Self.agentTokenProxyOptimizationInput(stdout: result.stdout, stderr: result.stderr)
        let optimization = TokenOptimizationLayer(mode: mode).optimizeTerminalOutput(
            messageID: "agent-token-proxy-\(UUID().uuidString)",
            command: command,
            rawOutput: optimizationInput,
            exitCode: Int(result.status)
        )

        if optimization.wasOptimized {
            Self.persistAgentTokenProxyRawOutput(optimization.rawOutputRecord)
            var output = optimization.output
            if !output.hasSuffix("\n") {
                output.append("\n")
            }
            cliWriteStdout(output)
        } else {
            Self.writeAgentTokenProxyRawResult(result)
        }
        Darwin.exit(result.status)
    }

    private static func agentHookToolInputDictionary(from payload: [String: Any]) -> [String: Any]? {
        if let dict = agentHookJSONDictionary(from: payload["tool_input"])
            ?? agentHookJSONDictionary(from: payload["toolInput"]) {
            return dict
        }
        if let toolCall = payload["toolCall"] as? [String: Any] {
            return agentHookJSONDictionary(from: toolCall["args"])
                ?? agentHookJSONDictionary(from: toolCall["input"])
        }
        if agentHookCommandKey(in: payload) != nil {
            return payload
        }
        return nil
    }

    private static func agentHookJSONDictionary(from raw: Any?) -> [String: Any]? {
        if let dict = raw as? [String: Any] {
            return dict
        }
        if let string = raw as? String,
           let data = string.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return nil
    }

    private static func agentHookString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let raw = dictionary[key] as? String else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static func agentHookCommandKey(in dictionary: [String: Any]) -> String? {
        for key in ["command", "cmd"] {
            guard let command = dictionary[key] as? String else { continue }
            if !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return key
            }
        }
        return nil
    }

    private static func agentHookCommandEligibleForTokenProxy(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("agent-token-proxy")
        else {
            return false
        }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("git status") {
            return true
        }
        if lowercased.contains(" test")
            || lowercased.hasSuffix(" test")
            || lowercased.contains("swift test")
            || lowercased.contains("xcodebuild test")
            || lowercased.contains("rspec")
            || lowercased.contains("vitest")
            || lowercased.contains("jest") {
            return true
        }
        if lowercased.contains("tsc")
            || lowercased.contains("typescript")
            || lowercased.contains("typecheck")
            || lowercased.contains("types:check") {
            return true
        }
        if lowercased == "npm install"
            || lowercased.hasPrefix("npm install ")
            || lowercased == "yarn install"
            || lowercased.hasPrefix("yarn install ")
            || lowercased == "bun install"
            || lowercased.hasPrefix("bun install ")
            || lowercased == "pnpm install"
            || lowercased.hasPrefix("pnpm install ")
            || lowercased == "bundle install"
            || lowercased.hasPrefix("bundle install ")
            || lowercased == "pod install"
            || lowercased.hasPrefix("pod install ") {
            return true
        }

        let commandName = trimmed.split(separator: " ").first.map(String.init) ?? ""
        return ["rg", "grep", "find", "tree"].contains(commandName)
            || lowercased.hasPrefix("ls -r")
    }

    private static func agentTokenProxyShellCommand(command: String, cwd: String?) -> String {
        var arguments = "agent-token-proxy --command-hex '\(lowercaseHexString(from: Data(command.utf8)))'"
        if let cwd,
           !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += " --cwd-hex '\(lowercaseHexString(from: Data(cwd.utf8)))'"
        }
        return [
            "bmux_cli=\"${BMUX_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$bmux_cli\" ] || [ ! -x \"$bmux_cli\" ]; then bmux_cli=\"$(command -v bmux 2>/dev/null || printf bmux)\"; fi",
            "\"$bmux_cli\" \(arguments)",
        ].joined(separator: "; ")
    }

    private static func writeAgentHookJSONObject(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        cliWriteStdout(data)
        cliWriteStdout(Data("\n".utf8))
    }

    private static func writeAgentTokenProxyRawResult(_ result: CLIProcessResult) {
        cliWriteStdout(result.stdout)
        cliWriteStderr(result.stderr)
    }

    private static func agentTokenProxyOptimizationInput(stdout: String, stderr: String) -> String {
        if !stdout.isEmpty {
            return stdout
        }
        return stderr
    }

    private static func persistAgentTokenProxyRawOutput(_ record: ChatRawTerminalOutputRecord) {
        guard let rawOutputRef = record.metadata.rawOutputRef,
              !rawOutputRef.isEmpty else {
            return
        }
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = root
            .appendingPathComponent("bmux", isDirectory: true)
            .appendingPathComponent("agent-raw-output", isDirectory: true)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let fileName = rawOutputRef.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
        guard !fileName.isEmpty else { return }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(record)
            try data.write(
                to: directory.appendingPathComponent(fileName).appendingPathExtension("json"),
                options: [.atomic]
            )
        } catch {
            return
        }
    }

    private static func currentAgentTokenOptimizationMode() -> TokenOptimizationMode {
        let catalog = SettingCatalog()
        let store = JSONConfigStore(fileURL: BmuxConfigLocation().userConfigFile)
        switch store.snapshotValue(for: catalog.terminal.agentTokenOptimizationMode) {
        case .off:
            return .off
        case .conservative:
            return .conservative
        case .balanced:
            return .balanced
        case .aggressive:
            return .aggressive
        }
    }

    private static func agentTokenProxyShellPath() -> String {
        let fileManager = FileManager.default
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           fileManager.isExecutableFile(atPath: shell) {
            return shell
        }
        if fileManager.isExecutableFile(atPath: "/bin/zsh") {
            return "/bin/zsh"
        }
        return "/bin/sh"
    }

    private static func lowercaseHexString(from data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var output = [UInt8]()
        output.reserveCapacity(data.count * 2)
        for byte in data {
            output.append(digits[Int(byte >> 4)])
            output.append(digits[Int(byte & 0x0f)])
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func stringFromLowercaseHex(_ hex: String) -> String? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count.isMultiple(of: 2),
              !trimmed.isEmpty else {
            return nil
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(trimmed.count / 2)
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let next = trimmed.index(index, offsetBy: 2)
            guard let byte = UInt8(trimmed[index..<next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }
        return String(data: Data(bytes), encoding: .utf8)
    }

    static func codexFireAndForgetAgentHookShellCommand(_ command: String, for def: AgentHookDef) -> String {
        let routedArguments = command.hasPrefix("bmux ") ? String(command.dropFirst("bmux ".count)) : command
        let runner = "payload=\"$1\"; shift; \"$@\" <\"$payload\" >/dev/null 2>&1 & child=\"$!\"; ( sleep 30; kill \"$child\" 2>/dev/null || true ) & watchdog=\"$!\"; wait \"$child\" 2>/dev/null || true; kill \"$watchdog\" 2>/dev/null || true; rm -f \"$payload\""
        return [
            "bmux_cli=\"${BMUX_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$bmux_cli\" ] || [ ! -x \"$bmux_cli\" ]; then bmux_cli=\"$(command -v bmux 2>/dev/null || true)\"; fi",
            "agent_pid=\"${BMUX_CODEX_PID:-${PPID:-}}\"",
            "if [ -n \"$BMUX_SURFACE_ID\" ] && [ \"$\(def.disableEnvVar)\" != \"1\" ] && [ -n \"$bmux_cli\" ]; then payload=\"$(mktemp \"${TMPDIR:-/tmp}/bmux-codex-hook.XXXXXX\" 2>/dev/null || mktemp -t bmux-codex-hook 2>/dev/null)\" || { echo '{}'; exit 0; }; cat >\"$payload\" || true; if [ -n \"${BMUX_SOCKET_PATH:-}\" ]; then BMUX_CODEX_PID=\"$agent_pid\" nohup sh -c '\(runner)' bmux-codex-hook \"$payload\" \"$bmux_cli\" --socket \"$BMUX_SOCKET_PATH\" \(routedArguments) >/dev/null 2>&1 & else BMUX_CODEX_PID=\"$agent_pid\" nohup sh -c '\(runner)' bmux-codex-hook \"$payload\" \"$bmux_cli\" \(routedArguments) >/dev/null 2>&1 & fi; echo '{}'; else echo '{}'; fi",
        ].joined(separator: "; ")
    }
}
