import Foundation
@testable import BmuxRemoteSession

/// Scripts the real bootstrap subprocess boundary; no executable is launched.
struct RemoteDaemonBootstrapProcessRunner: RemoteSessionProcessRunning {
    enum Event: Equatable, Sendable {
        case probe, hello, createDirectory
        case upload(destination: String, source: String)
    }

    let capabilities: [String]
    let events: AsyncStream<Event>.Continuation

    func run(_ request: RemoteProcessRequest, operation: (any RemoteTransferCancelling)?) throws -> RemoteCommandResult {
        let command = request.arguments.last ?? ""
        if request.executable == "/usr/bin/ssh" {
            if command.contains("uname -s") {
                events.yield(.probe)
                return RemoteCommandResult(status: 0, stdout: """
                    __BMUX_REMOTE_HOME__=/home/test
                    __BMUX_REMOTE_OS__=Linux
                    __BMUX_REMOTE_ARCH__=x86_64
                    __BMUX_REMOTE_EXISTS__=yes
                    """, stderr: "")
            }
            if command.contains("serve") && command.contains("--stdio") {
                events.yield(.hello)
                let response = try JSONSerialization.data(withJSONObject: [
                    "id": 1, "ok": true,
                    "result": ["name": "bmuxd-remote", "version": "old", "capabilities": capabilities],
                ])
                return RemoteCommandResult(status: 0, stdout: String(decoding: response, as: UTF8.self) + "\n", stderr: "")
            }
            if command.contains("mkdir -p") {
                events.yield(.createDirectory)
                return RemoteCommandResult(status: 0, stdout: "", stderr: "")
            }
        }
        if request.executable == "/usr/bin/scp", request.arguments.count >= 2 {
            events.yield(.upload(destination: command, source: request.arguments[request.arguments.count - 2]))
            return RemoteCommandResult(status: 1, stdout: "", stderr: "intentional stop after capability reinstall")
        }
        throw RemoteDaemonBootstrapFixture.Failure.unexpectedOperation
    }
}
