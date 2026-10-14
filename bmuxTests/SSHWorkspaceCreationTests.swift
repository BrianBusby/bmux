import Foundation
import Testing

@Suite
final class SSHWorkspaceCreationTests {
    @Test(arguments: [true, false])
    func configuresAndSelectsCreatedWorkspace(includesSurface: Bool) async throws {
        let fixture = try SSHWorkspaceCreationFixture()
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let requests = try await fixture.run(cli: cli, includesSurface: includesSurface)
        let expectedMethods = ["workspace.create"] + (includesSurface ? [] : ["surface.list"])
            + ["workspace.rename", "workspace.remote.configure", "workspace.select"]
        #expect(requests.compactMap { $0["method"] as? String } == expectedMethods)
        func params(_ method: String) throws -> [String: Any] {
            let request = try #require(requests.first { $0["method"] as? String == method })
            return try #require(request["params"] as? [String: Any])
        }
        let create = try params("workspace.create")
        #expect(create["window_id"] as? String == fixture.windowID)
        let initial = try #require(create["initial_command"] as? String)
        #expect(!initial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let rename = try params("workspace.rename")
        #expect(rename["workspace_id"] as? String == fixture.workspaceID)
        #expect(rename["title"] as? String == "SSH Workspace")
        let configure = try params("workspace.remote.configure")
        #expect(configure["workspace_id"] as? String == fixture.workspaceID)
        #expect(configure["destination"] as? String == "bmux-macmini")
        #expect(configure["port"] as? Int == 2222)
        #expect(configure["identity_file"] as? String == "/Users/test/.ssh/id_ed25519")
        #expect(configure["local_socket_path"] as? String == fixture.socketPath)
        #expect(configure["auto_connect"] as? Bool == false)
        #expect(try #require(configure["relay_port"] as? Int) > 0)
        let relayID = try #require(configure["relay_id"] as? String)
        #expect(!relayID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(try #require(configure["relay_token"] as? String).count == 64)
        let auth = try #require(configure["foreground_auth_token"] as? String)
        #expect(!auth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let startup = try #require(configure["terminal_startup_command"] as? String)
        #expect(!startup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let options = try #require(configure["ssh_options"] as? [String])
        for option in ["ControlMaster=auto", "ControlPersist=600", "ControlPath /tmp/bmux-ssh-%C", "StrictHostKeyChecking=accept-new"] {
            #expect(options.contains(option))
        }
        let select = try params("workspace.select")
        #expect(select["workspace_id"] as? String == fixture.workspaceID)
        #expect(select["window_id"] as? String == fixture.windowID)
    }
}
