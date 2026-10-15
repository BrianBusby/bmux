import Foundation
import Testing

@Suite
final class ClaudeNotificationTargetTests {
    @Test(arguments: [false, true])
    func staleSessionFallsBackToLiveWorkspace(permission: Bool) async throws {
        try await verify(routing: .staleSession, permission: permission)
    }

    @Test(arguments: [false, true])
    func explicitWorkspaceHandleResolvesTarget(permission: Bool) async throws {
        try await verify(routing: .explicitWorkspaceRef, permission: permission)
    }

    private func verify(routing: ClaudeNotificationTargetFixture.Routing, permission: Bool) async throws {
        let fixture = try ClaudeNotificationTargetFixture(
            routing: routing, processTimeout: CLIProcessTestTimeout().seconds(5)
        )
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let commands = try await fixture.run(cli: cli, permission: permission)
        let status = permission ? "Needs input" : "Idle"
        let statusCommands = commands.filter { $0.hasPrefix("set_status ") }
        #expect(statusCommands.count == 1)
        #expect(statusCommands.contains {
            $0.hasPrefix("set_status claude_code \(status) ") &&
                $0.contains("--tab=\(fixture.targetWorkspaceID)") &&
                $0.contains("--panel=\(fixture.targetSurfaceID)")
        }, "\(commands)")
        let notifications = commands.filter { $0.hasPrefix("notify_target") }
        #expect(notifications.count == 1)
        #expect(notifications.first?.hasPrefix("notify_target_async \(fixture.targetWorkspaceID) \(fixture.targetSurfaceID) ") == true)
        for forbidden in [fixture.staleWorkspaceID, fixture.focusedWorkspaceID] {
            #expect(!commands.contains {
                ($0.hasPrefix("set_status ") || $0.hasPrefix("notify_target")) && $0.contains(forbidden)
            }, "Must not route to \(forbidden): \(commands)")
        }
    }
}
