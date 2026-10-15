import BmuxFoundation
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a Cloud attach subprocess and the app-shaped errors delivered over its socket.
final class CloudAttachRetryFixture {
    enum Entry: CaseIterable, Sendable { case ssh, pty, session }
    enum Scenario: CaseIterable, Sendable {
        case genericOverride, legacyFallback, zeroLimit, ordinaryAttach, reconnect, permanentFailure, missingVM
    }

    let root: URL

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("cloud-retry-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(cli: String, entry: Entry, scenario: Scenario) async throws -> (commands: [String], stderr: String, error: String) {
        let method: String
        var arguments: [String]
        switch entry {
        case .ssh: method = "vm.ssh_info"; arguments = ["vm", "ssh-attach"]
        case .pty: method = "vm.attach_info"; arguments = ["vm-pty-attach"]
        case .session: method = "vm.session_attach_info"; arguments = ["vm-pty-attach"]
        }
        arguments += ["--id", "vm-retry-contract"]
        if entry == .session { arguments += ["--session", "session-contract", "--attachment", "attachment-contract"] }
        let usesDefault = scenario != .ordinaryAttach
        if usesDefault { arguments.append("--default-freestyle-sshd") }
        let socketPath = root.appendingPathComponent("socket").path
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_SOCKET_PATH": socketPath, "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
            "BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT": "120",
            "BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS": "2",
        ]
        if scenario == .legacyFallback {
            environment["BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_LIMIT"] = "1"
            environment["BMUX_DEFAULT_FREESTYLE_ATTACH_RETRY_DELAY_SECONDS"] = "0"
        } else {
            environment["BMUX_CLOUD_ATTACH_RETRY_LIMIT"] = scenario == .zeroLimit ? "0" : "1"
            environment["BMUX_CLOUD_ATTACH_RETRY_DELAY_SECONDS"] = "0"
        }
        if scenario == .reconnect { environment["BMUX_CLOUD_RECONNECT_ATTEMPT"] = "1" }
        let errorMessage = try cloudError(scenario: scenario)
        let server = CLISocketFixture(path: socketPath) { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            try #require(request["method"] as? String == method, "Unexpected mutation: \(line)")
            let id = try #require(request["id"] as? String)
            let params = try #require(request["params"] as? [String: Any])
            var expected: [String: Any] = ["id": "vm-retry-contract"]
            if entry == .session {
                expected["session_id"] = "session-contract"
                expected["attachment_id"] = "attachment-contract"
            } else if entry == .pty, usesDefault { expected["require_daemon"] = true }
            #expect(NSDictionary(dictionary: params).isEqual(to: expected), "\(line)")
            // v2VmCall wraps VMClientError descriptions under vm_error; the HTTP code remains in the message.
            let response: [String: Any] = ["id": id, "ok": false,
                                          "error": ["code": "vm_error", "message": errorMessage]]
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
        let runner = CommandRunner(environment: environment)
        let (result, commands) = try await server.capture {
            // Owned output files avoid blocking cooperative pipe readers while the socket task responds.
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "cli=$1; output=$2; errors=$3; shift 3; exec \"$cli\" \"$@\" </dev/null >\"$output\" 2>\"$errors\"",
                "cloud-attach-retry", cli, stdout.path, stderr.path,
            ] + arguments, timeout: CLIProcessTestTimeout().seconds(5))
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errorText = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 1, "\(errorText)")
        #expect(try String(contentsOf: stdout, encoding: .utf8).isEmpty)
        return (commands, errorText, errorMessage)
    }

    private func cloudError(scenario: Scenario) throws -> String {
        let status: Int
        let body: [String: Any]
        switch scenario {
        case .permanentFailure:
            status = 403
            body = ["error": "permission_denied", "message": "This Cloud VM request was not allowed."]
        case .missingVM:
            status = 404
            body = ["error": "vm_not_found", "message": "This VM was not found."]
        default:
            status = 502
            body = ["error": "vm_cloud_service_unavailable", "message": "bmux could not attach to the Cloud VM yet.",
                    "retryable": true, "retryAfterSeconds": 2,
                    "ui": ["title": "Reconnecting Cloud VM", "message": "bmux could not attach to the Cloud VM yet."]]
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        return VMClientError.httpStatus(status, String(decoding: data, as: UTF8.self)).description
    }
}
