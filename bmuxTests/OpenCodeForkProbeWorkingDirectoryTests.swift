import BMUXAgentLaunch
import BmuxCore
import Foundation
import Testing
@testable import bmux_DEV

@Suite
struct OpenCodeForkProbeWorkingDirectoryTests {
    @Test
    func probesFromLaunchWorkingDirectory() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("bmux-opencode-probe-\(UUID().uuidString)", isDirectory: true)
        let executable = root.appendingPathComponent("opencode", isDirectory: false)
        defer {
            do {
                try fileManager.removeItem(at: root)
            } catch {
                Issue.record(error, "Failed to remove owned OpenCode probe directory")
            }
        }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try """
        #!/bin/sh
        echo 'opencode 1.14.50'
        """.write(to: executable, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let snapshot = SessionRestorableAgentSnapshot(
            kind: .opencode,
            sessionId: "opencode-session-123",
            workingDirectory: root.path,
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "opencode",
                executablePath: "opencode",
                arguments: ["opencode"],
                workingDirectory: root.path,
                environment: ["PATH": ".:/usr/bin:/bin"],
                capturedAt: 123,
                source: "process"
            )
        )

        let supportsFork = await AgentForkSupport.supportsFork(snapshot: snapshot)
        #expect(supportsFork)
    }
}
