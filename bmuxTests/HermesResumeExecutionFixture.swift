import BmuxFoundation
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the executables, configuration, working directories and I/O for one resume.
final class HermesResumeExecutionFixture {
    enum Scenario: CaseIterable { case staleProvider, capturedExecutable, guardedRelative, explicitProvider }

    let root: URL
    let scenario: Scenario
    let baseURL = "http://subrouter-team:31415/v1"
    var project: URL { root.appendingPathComponent("Hermes team's project") }
    var codexHome: URL { root.appendingPathComponent("codex") }
    var executable: URL {
        switch scenario {
        case .staleProvider: return root.appendingPathComponent("bin/hermes")
        case .guardedRelative: return project.appendingPathComponent("hermes")
        case .capturedExecutable, .explicitProvider: return root.appendingPathComponent("captured bin/hermes")
        }
    }

    init(scenario: Scenario) throws {
        self.scenario = scenario
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-resume-\(UUID().uuidString)").resolvingSymlinksInPath()
        for directory in [project, codexHome, root.appendingPathComponent("bin"),
                          root.appendingPathComponent("captured bin"), root.appendingPathComponent("home"),
                          root.appendingPathComponent("inherited cwd")] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try """
        model = "gpt-5.5"
        openai_base_url = "http://subrouter-team:31415/v1"
        chatgpt_base_url = "http://subrouter-team:31415/backend-api"
        """.write(to: codexHome.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try "export PATH=\"$HERMES_RESUME_BIN:/usr/bin:/bin:/usr/sbin:/sbin\"\n".write(
            to: root.appendingPathComponent("home/.zprofile"), atomically: true, encoding: .utf8
        )
        let recorder = #"""
        #!/bin/sh
        {
          printf '%s\0' "$0" "$PWD" "${CUSTOM_BASE_URL-}" "${CODEX_HOME-}" "$#"
          if [ "$#" -gt 0 ]; then printf '%s\0' "$@"; fi
        } >> "$HERMES_RESUME_TEST_LOG"
        """#
        // A PATH fallback exists too; exact executable assertions detect accidental substitution.
        for location in [root.appendingPathComponent("bin/hermes"), executable] {
            try recorder.write(to: location, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: location.path)
        }
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run() async throws -> [HermesResumeInvocation] {
        let executableWord: String
        switch scenario {
        case .staleProvider: executableWord = "hermes"
        case .guardedRelative: executableWord = "./hermes"
        case .capturedExecutable, .explicitProvider: executableWord = executable.path
        }
        let provider = scenario == .explicitProvider ? "anthropic" : scenario == .staleProvider ? "openai-codex" : "custom"
        let prefix = scenario == .guardedRelative
            ? "cd -- \(quote(project.path)) 2>/dev/null || [ ! -d \(quote(project.path)) ] && "
            : "cd \(quote(project.path)) && "
        let binding = SurfaceResumeBindingSnapshot(
            kind: "hermes-agent",
            command: prefix + "\(quote(executableWord)) '--provider' \(quote(provider)) '--resume' 'hermes-session-123'",
            cwd: project.path, source: "agent-hook",
            environment: ["CODEX_HOME": codexHome.path, "CUSTOM_BASE_URL": baseURL], autoResume: true
        )
        let generated = Workspace.surfaceResumeStartupInput(
            binding, autoResumeAgentSessions: true, promptForApproval: false,
            approvalStoreURL: root.appendingPathComponent("approval.json"),
            approvalSigningSecret: Data("owned-resume-test-signing-key".utf8)
        )
        let command = try #require(generated)
        let script = root.appendingPathComponent("startup.zsh")
        try command.write(to: script, atomically: true, encoding: .utf8)
        let log = root.appendingPathComponent("invocations")
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let home = root.appendingPathComponent("home").path
        let runner = CommandRunner(environment: [
            "HOME": home, "CFFIXED_USER_HOME": home, "ZDOTDIR": home,
            "PATH": root.appendingPathComponent("bin").path + ":/usr/bin:/bin:/usr/sbin:/sbin",
            "SHELL": "/bin/zsh", "HERMES_RESUME_TEST_LOG": log.path,
            "HERMES_RESUME_BIN": root.appendingPathComponent("bin").path,
        ])
        let result = await runner.run(
            directory: root.appendingPathComponent("inherited cwd").path, executable: "/bin/sh",
            arguments: ["-c", "exec /bin/zsh -f \"$1\" </dev/null >\"$2\" 2>\"$3\"",
                        "hermes-startup", script.path, stdout.path, stderr.path], timeout: 5
        )
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errors)")
        #expect(errors.isEmpty)
        return try readInvocations(at: log)
    }

    private func readInvocations(at log: URL) throws -> [HermesResumeInvocation] {
        let data = try Data(contentsOf: log)
        var fields = data.split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
        try #require(fields.last == "")
        fields.removeLast()
        var cursor = 0
        var records: [HermesResumeInvocation] = []
        while cursor < fields.count {
            try #require(fields.count - cursor >= 5)
            let count = try #require(Int(fields[cursor + 4]))
            try #require(count >= 0 && fields.count - cursor - 5 >= count)
            let directory = URL(fileURLWithPath: fields[cursor + 1], isDirectory: true).resolvingSymlinksInPath()
            let executable = URL(fileURLWithPath: fields[cursor], relativeTo: directory).resolvingSymlinksInPath()
            records.append(HermesResumeInvocation(
                executable: executable.path, directory: directory.path,
                baseURL: fields[cursor + 2], codexHome: fields[cursor + 3],
                arguments: Array(fields[(cursor + 5)..<(cursor + 5 + count)])
            ))
            cursor += 5 + count
        }
        return records
    }

    private func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
