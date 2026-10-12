import Foundation
import Testing

@Suite
final class SSHStaleControlSocketTests {
    @Test func removesStaleControlSocketBeforeManagedAttach() async throws {
        let fixture = try SSHStaleControlSocketFixture()
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let result = try await fixture.run(cli: cli)
        #expect(!FileManager.default.fileExists(atPath: fixture.stalePath))
        let sshLog = try String(contentsOf: fixture.root.appendingPathComponent("ssh.log"), encoding: .utf8)
        #expect(sshLog.contains("-G"), "\(sshLog)")
        #expect(sshLog.contains("-O check"), "\(sshLog)")
        #expect(result.bridgeEvents == ["attach \(fixture.session) \(fixture.surface)"])
        let methods = try result.commands.map { line in
            let object = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            return try #require(object["method"] as? String)
        }
        #expect(methods.filter { $0 != "workspace.remote.pty_resize" } == [
            "workspace.remote.pty_bridge", "workspace.remote.pty_sessions",
            "workspace.remote.pty_attach_end", "workspace.remote.terminal_session_end",
        ], "\(result.commands)")
    }
}
