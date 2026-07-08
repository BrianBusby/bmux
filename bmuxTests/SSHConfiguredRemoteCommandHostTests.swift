import Darwin
import Foundation
import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

// Regression coverage for https://github.com/manaflow-ai/bmux/issues/7246:
// `bmux ssh` against a host whose ~/.ssh/config sets `RequestTTY yes` and
// `RemoteCommand sudo su -` fails with OpenSSH's
// "Cannot execute command-line and remote command." (exit 255) and loops the
// reconnect banner. Every bmux-controlled ssh invocation that supplies its own
// remote command must override the host-configured RemoteCommand (e.g.
// `-o RemoteCommand=none`), while the session hop that intentionally carries
// bmux's own `-o RemoteCommand=<bootstrap>` keeps doing so.
//
// The fake `ssh` below mirrors OpenSSH's actual rule: a positional remote
// command is fatal iff no `-o RemoteCommand=...` override appears on the argv
// (the first RemoteCommand option wins, like OpenSSH's first-obtained-value
// semantics). It records one `invocation kind=<...> override=<...>` event per
// spawn so assertions can distinguish config dumps, control operations,
// interactive sessions, and command-carrying invocations.
extension CLINotifyProcessIntegrationRegressionTests {
    /// `bmux ssh` default flow (ControlMaster/ControlPath defaults →
    /// foreground auth + persistent SSH PTY attach): the foreground auth hop
    /// runs `ssh ... <dest> true`, which a host-configured RemoteCommand used
    /// to break before the attach could ever start.
    func testSSHStartupConnectsWhenHostConfigSetsRemoteCommandAndRequestTTY() throws {
        let cliPath = try bundledCLIPath()
        let socketPath = makeSocketPath("ssh-rc-host")
        let listenerFD = try bindUnixSocket(at: socketPath)
        let workspaceID = "11111111-1111-1111-1111-111111111111"
        let surfaceID = "22222222-2222-2222-2222-222222222222"
        let sessionID = "ssh-\(workspaceID)-\(surfaceID)"

        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
        }

        // Phase 1: capture the generated startup command from the CLI.
        let captureState = MockSocketServerState()
        let captureHandled = startMockServer(listenerFD: listenerFD, state: captureState) { line in
            guard let payload = self.jsonObject(line),
                  let id = payload["id"] as? String,
                  let method = payload["method"] as? String else {
                return self.malformedRequestResponse(raw: line)
            }
            switch method {
            case "workspace.create":
                return self.v2Response(id: id, ok: true, result: [
                    "workspace_id": workspaceID,
                    "surface_id": surfaceID,
                ])
            case "workspace.remote.configure":
                return self.v2Response(id: id, ok: true, result: [
                    "workspace_id": workspaceID,
                    "workspace_ref": "workspace:9",
                    "remote": ["enabled": true, "state": "connecting"],
                ])
            default:
                return self.v2Response(
                    id: id,
                    ok: false,
                    error: ["code": "unexpected", "message": "Unexpected method \(method)"]
                )
            }
        }

        var captureEnvironment = ProcessInfo.processInfo.environment
        captureEnvironment["BMUX_SOCKET_PATH"] = socketPath
        captureEnvironment["BMUX_CLI_SENTRY_DISABLED"] = "1"
        captureEnvironment["BMUX_CLAUDE_HOOK_SENTRY_DISABLED"] = "1"

        let captureResult = runProcess(
            executablePath: cliPath,
            arguments: ["ssh", "--no-focus", "bmux-remotecommand-host"],
            environment: captureEnvironment,
            timeout: 5
        )
        wait(for: [captureHandled], timeout: 5)
        XCTAssertFalse(captureResult.timedOut, captureResult.stderr)
        XCTAssertEqual(captureResult.status, 0, captureResult.stderr)

        let requests = captureState.commands.compactMap(jsonObject)
        let createParams = try XCTUnwrap(
            requests.first { $0["method"] as? String == "workspace.create" }?["params"] as? [String: Any]
        )
        let startupCommand = try XCTUnwrap(createParams["initial_command"] as? String)

        // Phase 2: the attach leg of the startup script connects back for the
        // remote PTY bridge once foreground auth has succeeded.
        let bridge = try bindLoopbackTCP()
        defer { Darwin.close(bridge.fd) }
        let bridgeInput = MockBridgeInputCapture()
        let bridgeHandled = startBridgeReadyCapturingInputUntilEOF(listenerFD: bridge.fd, capture: bridgeInput)
        let attachState = MockSocketServerState()
        let attachHandled = startMockServer(listenerFD: listenerFD, state: attachState) { line in
            guard let payload = self.jsonObject(line),
                  let id = payload["id"] as? String,
                  let method = payload["method"] as? String else {
                return self.malformedRequestResponse(raw: line)
            }
            switch method {
            case "workspace.remote.pty_bridge":
                return self.v2Response(id: id, ok: true, result: [
                    "host": "127.0.0.1",
                    "port": bridge.port,
                    "token": "bridge-token",
                    "session_id": sessionID,
                    "attachment_id": surfaceID,
                ])
            case "workspace.remote.pty_sessions":
                return self.v2Response(id: id, ok: true, result: ["sessions": []])
            case "workspace.remote.pty_attach_end":
                return self.v2Response(id: id, ok: true, result: [
                    "workspace_id": workspaceID,
                    "surface_id": surfaceID,
                    "session_id": sessionID,
                    "cleared_remote_pty_session": true,
                ])
            default:
                return self.v2Response(
                    id: id,
                    ok: false,
                    error: ["code": "unexpected", "message": "Unexpected method \(method)"]
                )
            }
        }

        let harness = try makeRemoteCommandHostHarness(prefix: "bmux-ssh-rc-default")
        defer { harness.cleanup() }

        let startupResult = runProcess(
            executablePath: "/bin/sh",
            arguments: ["-c", startupCommand],
            environment: harness.startupEnvironment(
                socketPath: socketPath,
                workspaceID: workspaceID,
                surfaceID: surfaceID
            ),
            timeout: 10
        )

        XCTAssertFalse(startupResult.timedOut, startupResult.stderr)
        XCTAssertFalse(
            startupResult.stderr.contains("Cannot execute command-line and remote command."),
            "bmux-controlled ssh invocations must override a host-configured RemoteCommand; stderr: \(startupResult.stderr)"
        )
        XCTAssertFalse(
            startupResult.stderr.contains("[bmux] ssh exited with status"),
            startupResult.stderr
        )

        let events = harness.recordedSSHEvents()
        XCTAssertTrue(
            events.contains("invocation kind=command override=none"),
            "The foreground auth hop must pass -o RemoteCommand=none so a host-configured RemoteCommand cannot conflict with its command-line command; events: \(events)"
        )
        XCTAssertFalse(
            events.contains("invocation kind=command override=absent"),
            "A bmux-supplied command-line remote command reached ssh without a RemoteCommand override; events: \(events)"
        )

        wait(for: [attachHandled], timeout: 5)
        XCTAssertTrue(bridgeHandled.wait(timeout: .now() + 5) == .success)
        let attachMethods = attachState.commands.compactMap { self.jsonObject($0)?["method"] as? String }
        XCTAssertTrue(
            attachMethods.contains("workspace.remote.pty_bridge"),
            "Foreground auth should succeed and hand off to ssh-pty-attach; observed methods: \(attachMethods)"
        )
    }

    /// `bmux ssh` bootstrap-install flow (ControlMaster disabled → staged
    /// installer hop + interactive session hop): the installer hop pipes the
    /// bootstrap into `ssh ... <dest> <install command>` and used to hit the
    /// same fatal; the session hop must keep carrying bmux's own
    /// `-o RemoteCommand=<bootstrap>` rather than having it cleared.
    func testSSHBootstrapStartupConnectsWhenHostConfigSetsRemoteCommand() throws {
        let cliPath = try bundledCLIPath()
        let socketPath = makeSocketPath("ssh-rc-boot")
        let listenerFD = try bindUnixSocket(at: socketPath)
        let workspaceID = "11111111-1111-1111-1111-111111111111"

        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
        }

        let captureState = MockSocketServerState()
        let captureHandled = startMockServer(listenerFD: listenerFD, state: captureState) { line in
            guard let payload = self.jsonObject(line),
                  let id = payload["id"] as? String,
                  let method = payload["method"] as? String else {
                return self.malformedRequestResponse(raw: line)
            }
            switch method {
            case "workspace.create":
                return self.v2Response(id: id, ok: true, result: ["workspace_id": workspaceID])
            case "workspace.remote.configure":
                return self.v2Response(id: id, ok: true, result: [
                    "workspace_id": workspaceID,
                    "workspace_ref": "workspace:9",
                    "remote": ["enabled": true, "state": "connecting"],
                ])
            default:
                return self.v2Response(
                    id: id,
                    ok: false,
                    error: ["code": "unexpected", "message": "Unexpected method \(method)"]
                )
            }
        }

        var captureEnvironment = ProcessInfo.processInfo.environment
        captureEnvironment["BMUX_SOCKET_PATH"] = socketPath
        captureEnvironment["BMUX_CLI_SENTRY_DISABLED"] = "1"
        captureEnvironment["BMUX_CLAUDE_HOOK_SENTRY_DISABLED"] = "1"

        let captureResult = runProcess(
            executablePath: cliPath,
            arguments: [
                "ssh",
                "--no-focus",
                "--ssh-option", "ControlMaster no",
                "--ssh-option", "ControlPath /tmp/bmux-ssh-%C",
                "bmux-remotecommand-host",
            ],
            environment: captureEnvironment,
            timeout: 5
        )
        wait(for: [captureHandled], timeout: 5)
        XCTAssertFalse(captureResult.timedOut, captureResult.stderr)
        XCTAssertEqual(captureResult.status, 0, captureResult.stderr)

        let requests = captureState.commands.compactMap(jsonObject)
        let createParams = try XCTUnwrap(
            requests.first { $0["method"] as? String == "workspace.create" }?["params"] as? [String: Any]
        )
        let startupCommand = try XCTUnwrap(createParams["initial_command"] as? String)

        let harness = try makeRemoteCommandHostHarness(prefix: "bmux-ssh-rc-bootstrap")
        defer { harness.cleanup() }

        let startupResult = runProcess(
            executablePath: "/bin/sh",
            arguments: ["-c", startupCommand],
            environment: harness.startupEnvironment(
                socketPath: socketPath,
                workspaceID: workspaceID,
                surfaceID: "22222222-2222-2222-2222-222222222222"
            ),
            timeout: 10
        )

        XCTAssertFalse(startupResult.timedOut, startupResult.stderr)
        XCTAssertFalse(
            startupResult.stderr.contains("Cannot execute command-line and remote command."),
            "The bootstrap installer hop must override a host-configured RemoteCommand; stderr: \(startupResult.stderr)"
        )
        XCTAssertFalse(
            startupResult.stderr.contains("[bmux] ssh exited with status"),
            startupResult.stderr
        )
        XCTAssertEqual(startupResult.status, 0, startupResult.stderr)

        let events = harness.recordedSSHEvents()
        XCTAssertTrue(
            events.contains("invocation kind=command override=none"),
            "The bootstrap installer hop must pass -o RemoteCommand=none; events: \(events)"
        )
        XCTAssertFalse(
            events.contains("invocation kind=command override=absent"),
            "A bmux-supplied command-line remote command reached ssh without a RemoteCommand override; events: \(events)"
        )
        XCTAssertTrue(
            events.contains("invocation kind=session override=custom"),
            "The interactive session hop must keep carrying bmux's own -o RemoteCommand=<bootstrap>, not have it cleared to none; events: \(events)"
        )
    }

    /// The app-side restore/reattach startup script builder shares the same
    /// foreground-auth `ssh ... <dest> true` shape as the CLI.
    func testSSHPTYAttachForegroundAuthOverridesHostConfiguredRemoteCommand() throws {
        let command = SSHPTYAttachStartupCommandBuilder.command(
            sessionID: "ssh-w-s",
            foregroundAuth: SSHPTYAttachStartupCommandBuilder.ForegroundAuth(
                destination: "bmux-remotecommand-host",
                port: 2222,
                identityFile: nil,
                sshOptions: [
                    "ControlMaster=auto",
                    "ControlPersist=600",
                    "ControlPath=/tmp/bmux-ssh-%C",
                ],
                token: "auth-token"
            ),
            remoteCommand: "printf ready"
        )
        XCTAssertTrue(
            command.contains("-o RemoteCommand=none -T bmux-remotecommand-host true"),
            "Restore foreground auth must override a host-configured RemoteCommand before running its command-line `true`; command: \(command)"
        )
    }

    // MARK: - Fake RemoteCommand-host harness

    struct RemoteCommandHostHarness {
        let root: URL
        let binDirectory: URL
        let eventsFile: URL
        let fakeCLILog: URL

        func startupEnvironment(
            socketPath: String,
            workspaceID: String,
            surfaceID: String
        ) -> [String: String] {
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "\(binDirectory.path):\(environment["PATH"] ?? "/usr/bin:/bin")"
            environment["BMUX_BUNDLED_CLI_PATH"] = binDirectory.appendingPathComponent("bmux").path
            environment["BMUX_SOCKET_PATH"] = socketPath
            environment["BMUX_WORKSPACE_ID"] = workspaceID
            environment["BMUX_SURFACE_ID"] = surfaceID
            environment["BMUX_FAKE_SSH_EVENTS"] = eventsFile.path
            environment["BMUX_FAKE_CLI_LOG"] = fakeCLILog.path
            environment["BMUX_CLI_SENTRY_DISABLED"] = "1"
            environment["BMUX_CLAUDE_HOOK_SENTRY_DISABLED"] = "1"
            environment["BMUX_SSH_RECONNECT_LIMIT"] = "1"
            environment["BMUX_SSH_RECONNECT_DELAY_SECONDS"] = "0"
            return environment
        }

        func recordedSSHEvents() -> [String] {
            ((try? String(contentsOf: eventsFile, encoding: .utf8)) ?? "")
                .split(separator: "\n")
                .map(String.init)
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// Installs a fake `ssh` simulating a host whose ssh_config sets
    /// `RequestTTY yes` + `RemoteCommand sudo su -`, and a fake `bmux` for the
    /// startup script's session-end reporting.
    func makeRemoteCommandHostHarness(prefix: String) throws -> RemoteCommandHostHarness {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        let binDirectory = root.appendingPathComponent("bin", isDirectory: true)
        try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)

        let harness = RemoteCommandHostHarness(
            root: root,
            binDirectory: binDirectory,
            eventsFile: root.appendingPathComponent("fake-ssh-events.log"),
            fakeCLILog: root.appendingPathComponent("fake-cli.log")
        )

        // Mirrors OpenSSH: the first -o RemoteCommand=... wins; a positional
        // command with no override is fatal exactly like a host-configured
        // RemoteCommand conflict. `-G` prints a config dump and `-O` control
        // operations never execute a remote command.
        let fakeSSH = """
        #!/bin/sh
        events="${BMUX_FAKE_SSH_EVENTS:?}"
        override=absent
        mode=session
        while [ $# -gt 0 ]; do
          case "$1" in
            -o)
              if [ "$override" = absent ]; then
                case "$2" in
                  RemoteCommand=none|remotecommand=none) override=none ;;
                  RemoteCommand=*|remotecommand=*) override=custom ;;
                esac
              fi
              shift 2 ;;
            -o*)
              if [ "$override" = absent ]; then
                case "${1#-o}" in
                  RemoteCommand=none|remotecommand=none) override=none ;;
                  RemoteCommand=*|remotecommand=*) override=custom ;;
                esac
              fi
              shift ;;
            -G) mode=config; shift ;;
            -O) mode=controlop; shift 2 ;;
            -S|-p|-i|-l|-F|-E|-e|-b|-c|-D|-I|-J|-L|-m|-Q|-R|-W|-w|-B) shift 2 ;;
            --) shift; shift; break ;;
            -*) shift ;;
            *) shift; break ;;
          esac
        done
        if [ "$mode" = config ]; then
          printf 'invocation kind=config override=%s\\n' "$override" >> "$events"
          printf 'controlpath none\\n'
          exit 0
        fi
        if [ "$mode" = controlop ]; then
          printf 'invocation kind=controlop override=%s\\n' "$override" >> "$events"
          exit 0
        fi
        if [ $# -gt 0 ]; then mode=command; fi
        printf 'invocation kind=%s override=%s\\n' "$mode" "$override" >> "$events"
        if [ "$mode" = command ] && [ "$override" = absent ]; then
          printf '%s\\n' 'Cannot execute command-line and remote command.' >&2
          exit 255
        fi
        cat >/dev/null 2>&1 || true
        exit 0
        """
        let fakeSSHURL = binDirectory.appendingPathComponent("ssh")
        try fakeSSH.appending("\n").write(to: fakeSSHURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeSSHURL.path)

        let fakeCLI = """
        #!/bin/sh
        printf '%s\\n' "$*" >> "${BMUX_FAKE_CLI_LOG:?}"
        exit 0
        """
        let fakeCLIURL = binDirectory.appendingPathComponent("bmux")
        try fakeCLI.appending("\n").write(to: fakeCLIURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLIURL.path)

        return harness
    }
}
