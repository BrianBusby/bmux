import Foundation
import Testing

@Suite
final class CodexRejectedAmbientTests {
    @Test(arguments: [CodexRejectedAmbientFixture.Identity.invalidSurface, .foreignMapping],
          [CodexRejectedAmbientFixture.Binding.missing, .unlistedPID])
    func rejectedAmbientIdentityCannotGuessTarget(
        identity: CodexRejectedAmbientFixture.Identity, binding: CodexRejectedAmbientFixture.Binding
    ) async throws {
        let fixture = try CodexRejectedAmbientFixture(identity: identity)
        let commands = try await fixture.run(cli: cliPath(), binding: binding)
        try expectNoMutations(commands, fixture: fixture)
    }

    @Test(arguments: [CodexRejectedAmbientFixture.Identity.invalidSurface, .foreignMapping],
          [CodexRejectedAmbientFixture.Binding.missing, .unlistedPID])
    func rejectedStopIdentityCannotEmitFallbackTelemetry(
        identity: CodexRejectedAmbientFixture.Identity, binding: CodexRejectedAmbientFixture.Binding
    ) async throws {
        let fixture = try CodexRejectedAmbientFixture(identity: identity)
        let commands = try await fixture.run(cli: cliPath(), binding: binding, stop: true)
        try expectNoMutations(commands, fixture: fixture)
    }

    @Test(arguments: [CodexRejectedAmbientFixture.Identity.invalidSurface, .foreignMapping],
          [CodexRejectedAmbientFixture.Binding.pid, .tty])
    func rejectedAmbientIdentityRecoversWithVerifiedBinding(
        identity: CodexRejectedAmbientFixture.Identity, binding: CodexRejectedAmbientFixture.Binding
    ) async throws {
        let fixture = try CodexRejectedAmbientFixture(identity: identity)
        let commands = try await fixture.run(cli: cliPath(), binding: binding)
        try expectTarget(commands, fixture: fixture, surface: fixture.liveSurfaceID)
    }

    @Test(arguments: [CodexRejectedAmbientFixture.Identity.invalidSurface, .foreignMapping])
    func explicitInvalidIdentityRemainsNoOp(identity: CodexRejectedAmbientFixture.Identity) async throws {
        let fixture = try CodexRejectedAmbientFixture(identity: identity)
        let commands = try await fixture.run(cli: cliPath(), binding: .pid, explicit: true)
        try expectNoMutations(commands, fixture: fixture)
    }

    @Test(arguments: [CodexRejectedAmbientFixture.Identity.validAmbient, .workspaceMapping])
    func validAmbientOrSavedIdentityWorksWithoutLocalBinding(identity: CodexRejectedAmbientFixture.Identity) async throws {
        let fixture = try CodexRejectedAmbientFixture(identity: identity)
        let commands = try await fixture.run(cli: cliPath(), binding: .missing)
        try expectTarget(commands, fixture: fixture,
                         surface: identity == .validAmbient ? fixture.liveSurfaceID : fixture.focusedSurfaceID)
    }

    private func cliPath() throws -> String { try BundledCLITestSupport.bundledCLIPath(for: Self.self) }

    private func expectNoMutations(_ commands: [String], fixture: CodexRejectedAmbientFixture) throws {
        #expect(!commands.contains { !$0.hasPrefix("{") }, "No PID/lifecycle/status/notification mutation: \(commands)")
        let requests = try commands.filter { $0.hasPrefix("{") }.map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
        #expect(!requests.contains {
            ["surface.resume.set", "surface.resume.clear", "feed.push"].contains($0["method"] as? String ?? "")
        }, "No resume binding or wrong-target feed event: \(commands)")
        let session = try fixture.storedSession()
        #expect(session?["runtimeStatus"] == nil)
        #expect(session?["agentLifecycle"] == nil)
        #expect(session?["activePromptDepth"] == nil)
        if fixture.identity == .foreignMapping {
            #expect(session?["workspaceId"] as? String == fixture.workspaceID)
            #expect(session?["surfaceId"] as? String == fixture.focusedSurfaceID)
        } else { #expect(session == nil) }
    }

    private func expectTarget(_ commands: [String], fixture: CodexRejectedAmbientFixture, surface: String) throws {
        let status = commands.filter { $0.hasPrefix("set_status ") }
        #expect(status.count == 1)
        #expect(status.first?.hasPrefix("set_status codex Running ") == true)
        for command in commands where !command.hasPrefix("{") {
            #expect(command.contains("--tab=\(fixture.workspaceID)"), "\(command)")
            #expect(command.contains("--panel=\(surface)"), "\(command)")
        }
        let requests = try commands.filter { $0.hasPrefix("{") }.map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }.filter { $0["method"] as? String == "surface.resume.set" }
        #expect(requests.count == 1)
        let params = try #require(requests.first?["params"] as? [String: Any])
        #expect(params["workspace_id"] as? String == fixture.workspaceID)
        #expect(params["surface_id"] as? String == surface)
        let stored = try fixture.storedSession()
        let session = try #require(stored)
        #expect(session["workspaceId"] as? String == fixture.workspaceID)
        #expect(session["surfaceId"] as? String == surface)
        #expect(session["runtimeStatus"] as? String == "running")
    }
}
