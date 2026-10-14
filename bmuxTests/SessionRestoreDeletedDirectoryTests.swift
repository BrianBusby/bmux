import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct SessionRestoreDeletedDirectoryTests {
    @Test func restoreDoesNotPassDeletedAgentHookCwdToTerminalRuntime() throws {
        let suiteName = "bmux-deleted-agent-hook-cwd-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: AgentSessionAutoResumeSettings.autoResumeAgentSessionsKey)
        let source = Workspace(agentSessionAutoResumeDefaults: defaults)
        defer { source.teardownAllPanels() }
        let sourcePanelId = try #require(source.focusedPanelId)
        let missingCwd = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
            .appendingPathComponent("repo", isDirectory: true)
        let binding = SurfaceResumeBindingSnapshot(
            name: "Codex",
            kind: "codex",
            command: "cd '\(missingCwd.path)' && codex resume session-duplicate-turn --yolo",
            cwd: missingCwd.path,
            checkpointId: "session-duplicate-turn",
            source: "agent-hook",
            environment: ["CLAUDE_CONFIG_DIR": "/tmp/claude-profile"],
            autoResume: true,
            updatedAt: 10
        )
        let bindingIndex = SurfaceResumeBindingIndex(bindingsByPanel: [
            SurfaceResumeBindingIndex.PanelKey(workspaceId: source.id, panelId: sourcePanelId): binding,
        ])
        let snapshot = source.sessionSnapshot(includeScrollback: false, surfaceResumeBindingIndex: bindingIndex)
        let restored = Workspace(agentSessionAutoResumeDefaults: defaults)
        defer { restored.teardownAllPanels() }
        restored.restoreSessionSnapshot(snapshot)
        let restoredPanelId = try #require(restored.focusedPanelId)
        let restoredPanel = try #require(restored.terminalPanel(for: restoredPanelId))
        let startupCommand = try #require(restoredPanel.surface.debugInitialCommand())
        let launcherPrefix = "/bin/zsh '"
        try #require(startupCommand.hasPrefix(launcherPrefix) && startupCommand.hasSuffix("'"))
        let scriptPath = String(startupCommand.dropFirst(launcherPrefix.count).dropLast())
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }
        let startupPayload = try String(contentsOfFile: scriptPath, encoding: .utf8)

        #expect(restoredPanel.requestedWorkingDirectory == nil)
        #expect(startupPayload.contains("codex resume session-duplicate-turn -c check_for_update_on_startup=false --yolo"))
        // Fish parses the inline command; the outer #!/bin/zsh launcher may use
        // braces when returning the post-agent login shell to the saved directory.
        let inlineInput = try #require(binding.inlineStartupInput)
        #expect(!inlineInput.contains("{ cd -- "))
        let guardStart = try #require(startupPayload.range(of: "cd -- "))
        let guardSuffix = String(startupPayload[guardStart.lowerBound...])
        let guardEnd = try #require(guardSuffix.range(of: "] &&")?.upperBound)
        let guardSnippet = String(guardSuffix[..<guardEnd])
        #expect(guardSnippet.contains(missingCwd.path))
        #expect(guardSnippet.contains("2>/dev/null || [ ! -d"))
    }
}
