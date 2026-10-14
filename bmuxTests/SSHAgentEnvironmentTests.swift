import Foundation
import Testing

@Suite
final class SSHAgentEnvironmentTests {
    // Plain forwarding preserves the caller; explicit tilde paths win only when present.
    @Test(arguments: [(false, false), (true, true), (true, false)])
    func forwardsTheResolvedAgentPath(explicitTilde: Bool, candidateExists: Bool) async throws {
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ssh-agent-env-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".ssh"), withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned SSH agent fixture directory") }
        }
        let ambient = root.appendingPathComponent("ambient.sock")
        let candidate = root.appendingPathComponent(".ssh/agent.sock")
        // Path resolution only checks existence; these owned files never receive agent traffic.
        try Data().write(to: ambient)
        if candidateExists { try Data().write(to: candidate) }
        let socket = root.appendingPathComponent("socket").path
        let workspace = "11111111-1111-1111-1111-111111111111"
        let surface = "22222222-2222-2222-2222-222222222222"
        let server = CLISocketFixture(path: socket) { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            let result: [String: Any]
            switch method {
            case "workspace.create": result = ["workspace_id": workspace, "surface_id": surface]
            case "workspace.remote.configure": result = ["workspace_id": workspace, "remote": ["state": "connected"]]
            default:
                Issue.record("Unexpected SSH agent fixture method: \(method)")
                return String(decoding: try JSONSerialization.data(withJSONObject:
                    ["id": id, "ok": false, "error": ["code": "unexpected", "message": method]]), as: UTF8.self)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject:
                ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "SSH_AUTH_SOCK": ambient.path,
            "BMUX_SOCKET_PATH": socket, "BMUX_CLI_SENTRY_DISABLED": "1",
        ]
        let runner = ShellContractProcess(root: root, deadline: .seconds(5), terminationGrace: .milliseconds(200))
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let arguments = ["ssh", "example.test", "--no-focus"]
            + (explicitTilde ? ["--ssh-option", "ForwardAgent=~/.ssh/agent.sock"] : [])
        let (outcome, commands) = try await server.capture {
            // Join the producer on failures too, before the socket's completion drain.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await runner.run(
                    executable: cli, arguments: arguments, environment: environment
                ))
            } catch { return .failure(error) }
        }
        let result: ShellContractProcess.Result
        do { result = try outcome.get() }
        catch {
            let output = Result { try String(contentsOf: root.appendingPathComponent("stdout"), encoding: .utf8) }
            let errors = Result { try String(contentsOf: root.appendingPathComponent("stderr"), encoding: .utf8) }
            Issue.record(error, "SSH agent forwarding failed after requests: \(commands); stdout: \(output); stderr: \(errors)")
            throw error
        }
        let errors = result.stderr
        #expect(result.status == 0, "\(errors)")
        #expect(errors.isEmpty, "\(errors)")
        let requests = try commands.map { try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]) }
        #expect(requests.compactMap { $0["method"] as? String } == ["workspace.create", "workspace.remote.configure"])
        let create = try #require(requests.first?["params"] as? [String: Any])
        let configure = try #require(requests.last?["params"] as? [String: Any])
        let initialEnvironment = try #require(create["initial_env"] as? [String: String])
        let expected = explicitTilde && candidateExists ? candidate.path : ambient.path
        #expect(initialEnvironment["SSH_AUTH_SOCK"] == expected)
        #expect(configure["ssh_auth_sock"] as? String == expected)
        #expect(configure["workspace_id"] as? String == workspace)
        let options = configure["ssh_options"] as? [String] ?? []
        if explicitTilde {
            #expect(options.contains("ForwardAgent=~/.ssh/agent.sock"))
        } else {
            // Other defaults (e.g. multiplexing) do not override the caller's ForwardAgent configuration.
            #expect(!options.contains { $0.lowercased().split(whereSeparator: { $0 == "=" || $0.isWhitespace }).first == "forwardagent" })
        }
    }
}
