import Foundation
import Testing

struct SSHStartupManualReconnectTests {
    @Test(arguments: [
        ("r\n", 0, true), ("R\n", 0, true),
        ("retry\n", 0, true), ("reconnect\n", 0, true),
        ("\n", 0, true), ("", 0, true),
        ("r\n", 1, true), ("r\nr\n\n", 1, true),
        ("r\n", 0, false),
    ])
    func manualReconnectHandsOffToNativeOwner(input: String, rpcStatus: Int, hasSurface: Bool) async throws {
        let fileManager = FileManager.default
        let fixture = try SSHStartupManualReconnectFixture()
        let root = fixture.root
        let fakeCLI = root.appendingPathComponent("bmux")
        let fakeSSH = root.appendingPathComponent("ssh")
        let logFile = root.appendingPathComponent("ssh-session-end.log")
        let attemptFile = root.appendingPathComponent("ssh-attempts.txt")
        let credentialPathFile = root.appendingPathComponent("credential-path.txt")

        try fixture.writeShellFile(at: fakeCLI, lines: [
            "#!/bin/sh",
            "printf '%s\\n' \"$*\" >> \"${BMUX_TEST_SESSION_END_LOG}\"",
            "case \"$*\" in *'rpc workspace.remote.reconnect '*)",
            "  [ ! -e \"$(cat \"$BMUX_TEST_CREDENTIAL_PATH\")\" ] || exit 98",
            "  exit \"$BMUX_TEST_RPC_STATUS\" ;; esac",
        ])
        try fixture.writeShellFile(at: fakeSSH, lines: [
            "#!/bin/sh",
            "count=$(cat \"${BMUX_TEST_ATTEMPT_FILE}\" 2>/dev/null || printf 0)",
            "count=$((count + 1))",
            "printf '%s' \"$count\" > \"${BMUX_TEST_ATTEMPT_FILE}\"",
            "[ \"$(cat \"$BMUX_SSH_ASKPASS_FILE\")\" = lease-token ] || exit 97",
            "printf '%s' \"$BMUX_SSH_ASKPASS_FILE\" > \"$BMUX_TEST_CREDENTIAL_PATH\"",
            "exit 1",
        ])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeSSH.path)

        let startupCommand = try await fixture.generatedStartupCommand()
        var environment = fixture.environment
        environment["BMUX_BUNDLED_CLI_PATH"] = fakeCLI.path
        environment["BMUX_SOCKET_PATH"] = root.appendingPathComponent("owned.sock").path
        environment["BMUX_WORKSPACE_ID"] = "11111111-1111-1111-1111-111111111111"
        environment["BMUX_SURFACE_ID"] = "22222222-2222-2222-2222-222222222222"
        environment["BMUX_TEST_SESSION_END_LOG"] = logFile.path
        environment["BMUX_TEST_ATTEMPT_FILE"] = attemptFile.path
        environment["BMUX_TEST_CREDENTIAL_PATH"] = credentialPathFile.path
        environment["BMUX_TEST_RPC_STATUS"] = String(rpcStatus)
        if !hasSurface { environment.removeValue(forKey: "BMUX_SURFACE_ID") }
        environment["BMUX_SSH_RECONNECT_DELAY_SECONDS"] = "0"

        let result = try await fixture.runProcess(
            executablePath: "/bin/sh",
            arguments: ["-c", startupCommand],
            environment: environment,
            standardInput: input
        )

        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        let choices = input.split(separator: "\n").count
        let requests = hasSurface ? (rpcStatus == 0 ? min(choices, 1) : choices) : 0
        #expect(result.status == (requests > 0 && rpcStatus == 0 ? 0 : 1), Comment(rawValue: result.stderr))
        #expect(
            (try? String(contentsOf: attemptFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) == "1",
            "manual reconnect must hand off to the native owner without launching SSH again"
        )
        let recordedCalls = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
        let calls = recordedCalls.split(separator: "\n")
        let sessionEndCalls = calls.filter { $0.contains("ssh-session-end") }
        let reconnectCalls = calls.filter { $0.contains("rpc workspace.remote.reconnect ") }
        #expect(sessionEndCalls.count == (hasSurface ? 1 : 0), Comment(rawValue: recordedCalls))
        #expect(reconnectCalls.count == requests, Comment(rawValue: recordedCalls))
        if choices > 0 && (rpcStatus != 0 || !hasSurface) {
            #expect(result.stderr.contains("reconnect failed"), Comment(rawValue: result.stderr))
        }
        let credentialPath = try String(contentsOf: credentialPathFile, encoding: .utf8)
        #expect(!fileManager.fileExists(atPath: credentialPath), "one-shot credential must be removed before prompt handoff")
        if let sessionEndIndex = calls.firstIndex(where: { $0.contains("ssh-session-end") }),
           let reconnectIndex = calls.firstIndex(where: { $0.contains("rpc workspace.remote.reconnect ") }) {
            #expect(sessionEndIndex < reconnectIndex, "old session cleanup must precede the replacement grant")
        }
        #expect(
            requests == 0 || recordedCalls.contains("rpc workspace.remote.reconnect {\"workspace_id\":\"11111111-1111-1111-1111-111111111111\",\"surface_id\":\"22222222-2222-2222-2222-222222222222\"}"),
            Comment(rawValue: recordedCalls)
        )
    }

    @Test(arguments: [false, true], ["\n", ""])
    func bootstrapDismissalPreservesSSHExitStatus(reusable: Bool, input: String) async throws {
        let fixture = try SSHStartupManualReconnectFixture()
        let root = fixture.root
        let ssh = root.appendingPathComponent("ssh")
        let cli = root.appendingPathComponent("bmux")
        let calls = root.appendingPathComponent("calls")
        try fixture.writeShellFile(at: ssh, lines: ["#!/bin/sh", "exit 7"])
        try fixture.writeShellFile(at: cli, lines: ["#!/bin/sh", "printf '%s\\n' \"$*\" >> \"$BMUX_TEST_CALLS\""])
        for file in [ssh, cli] { try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path) }
        let command = try await fixture.generatedStartupCommand(bootstrap: true, reusable: reusable)
        var environment = fixture.environment
        environment["BMUX_BUNDLED_CLI_PATH"] = cli.path
        environment["BMUX_SOCKET_PATH"] = root.appendingPathComponent("owned.sock").path
        environment["BMUX_WORKSPACE_ID"] = "11111111-1111-1111-1111-111111111111"
        environment["BMUX_SURFACE_ID"] = "22222222-2222-2222-2222-222222222222"
        environment["BMUX_TEST_CALLS"] = calls.path
        let result = try await fixture.runProcess(executablePath: "/bin/sh", arguments: ["-c", command],
            environment: environment, standardInput: input)
        #expect(!result.timedOut)
        #expect(result.status == 7, Comment(rawValue: result.stderr))
        let recorded = try String(contentsOf: calls, encoding: .utf8).split(separator: "\n")
        #expect(recorded.count == 1)
        #expect(recorded.first?.contains("ssh-session-end") == true)
        #expect(!recorded.contains { $0.contains("rpc workspace.remote.reconnect") })
    }

}
