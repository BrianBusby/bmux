import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct WorkspaceOMXHudRestoreTests {
    @Test func sessionRestoreRelaunchesOMXHudTmuxStartCommand() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-hud-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned HUD restore directory") }
        }
        let suiteName = "bmux-hud-restore-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workspace = Workspace(agentSessionAutoResumeDefaults: defaults)
        defer { workspace.teardownAllPanels() }
        let sourcePanelId = try #require(workspace.focusedPanelId)
        let requestedDirectory = root.path
        let originalStartupScript = "/tmp/bmux-tmux-command-\(UUID().uuidString).sh"
        let tmuxStartCommand = "env OMX_SESSION_ID=omx-test node '/opt/oh-my-codex/dist/cli/omx.js' hud --watch"
        let hudPanel = try #require(workspace.newTerminalSplit(
            from: sourcePanelId,
            orientation: .vertical,
            insertFirst: false,
            focus: false,
            workingDirectory: requestedDirectory,
            initialCommand: originalStartupScript,
            tmuxStartCommand: tmuxStartCommand,
            initialDividerPosition: 0.82
        ))

        let snapshot = workspace.sessionSnapshot(includeScrollback: false)
        let hudSnapshot = try #require(snapshot.panels.first { $0.id == hudPanel.id })
        #expect(hudSnapshot.terminal?.tmuxStartCommand == tmuxStartCommand)

        let restored = Workspace(agentSessionAutoResumeDefaults: defaults)
        defer {
            // Capture only this owned HUD's generated launcher before tearing down panels.
            let scripts = restored.panels.values.compactMap { $0 as? TerminalPanel }
                .filter { $0.surface.debugTmuxStartCommand() == tmuxStartCommand }
                .compactMap { $0.surface.debugInitialCommand() }
            restored.teardownAllPanels()
            for script in scripts {
                do { try FileManager.default.removeItem(atPath: script) }
                catch { Issue.record(error, "Could not remove owned HUD restore launcher") }
            }
        }
        restored.restoreSessionSnapshot(snapshot)

        let restoredHudPanel = try #require(
            restored.panels.values
                .compactMap { $0 as? TerminalPanel }
                .first { $0.surface.debugTmuxStartCommand() == tmuxStartCommand }
        )
        let restoredStartupScript = try #require(restoredHudPanel.surface.debugInitialCommand())
        #expect(
            restoredStartupScript != originalStartupScript,
            "Restored HUD panes must launch through a fresh script, not a deleted tmux temp script"
        )
        #expect(restoredStartupScript.contains("bmux-session-terminal-command"))
        #expect(restoredHudPanel.requestedWorkingDirectory == requestedDirectory)
    }
}
