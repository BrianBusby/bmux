import Testing

struct GrokSiblingStatusTests {
    @Test func completionDoesNotResetStatusWhileSiblingSessionRuns() async throws {
        let fixture = try GrokSiblingStatusFixture()
        let runningSession = "grok-session-running", completingSession = "grok-session-completing"
        _ = try await fixture.run("session-start", session: runningSession, ambientSurface: fixture.runningSurface)
        _ = try await fixture.run("session-start", session: completingSession, ambientSurface: fixture.completingSurface)
        _ = try await fixture.run("stop", session: runningSession)
        let prompt = try await fixture.run("prompt-submit", session: runningSession, fields: ["prompt": "keep running"])
        #expect(prompt.contains("clear_notifications --tab=\(fixture.workspace) --panel=\(fixture.runningSurface)"))
        #expect(prompt.contains { $0.contains("set_status grok Running") })
        let completion = try await fixture.run("notification", session: completingSession,
            fields: ["message": "Turn complete in 1.0s."])
        #expect(completion.contains {
            $0.contains("notify_target_async \(fixture.workspace) \(fixture.completingSurface) Grok|Completed|Task completed")
        })
        #expect(!completion.contains { $0.contains("set_status grok Idle") })
    }
}
