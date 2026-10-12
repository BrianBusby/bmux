import Testing

@Suite
final class ClaudeNotificationStatusLifecycleTests {
    @Test(arguments: [false, true])
    func claudeNotificationStatusCarriesPIDForStaleSweep(permission: Bool) async throws {
        let claudePID = 42_424
        let fixture = try ClaudeNotificationTargetFixture(routing: .callerEnvironment, agentPID: claudePID)
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let commands = try await fixture.run(cli: cli, permission: permission)
        let status = permission ? "Needs input" : "Idle"
        let statusCommands = commands.filter { $0.hasPrefix("set_status ") }
        #expect(statusCommands.count == 1)
        let statusCommand = try #require(statusCommands.first)
        #expect(statusCommand.hasPrefix("set_status claude_code \(status) "), "\(commands)")
        let options = statusCommand.split(separator: " ")
        #expect(options.contains("--tab=\(fixture.targetWorkspaceID)"))
        #expect(options.contains("--panel=\(fixture.targetSurfaceID)"))
        #expect(
            options.contains("--pid=\(claudePID)"),
            "The status must carry the agent PID so stale sweeping can clear it after abrupt exit: \(statusCommand)"
        )
        let lifecycle = permission ? "needsInput" : "idle"
        #expect(commands.filter { $0.hasPrefix("set_agent_lifecycle ") } == [
            "set_agent_lifecycle claude_code \(lifecycle) --tab=\(fixture.targetWorkspaceID) --panel=\(fixture.targetSurfaceID)"
        ])
    }
}
