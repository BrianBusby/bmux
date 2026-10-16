import Foundation
import BmuxControlSocket
import BmuxCore
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite("Legacy remote directory trust")
struct WorkspaceLegacyRemoteDirectoryTrustTests {
    @MainActor
    @Test("legacy remote restore keeps persisted cwd untrusted until remote report")
    func legacyRemoteRestoreKeepsPersistedDirectoryUntrustedUntilRemoteReport() throws {
        // Automated-test restore policy prevents auto-connect; teardown must also avoid SSH cleanup.
        let priorCleanup = Workspace.runSSHControlMasterCommandOverrideForTesting
        Workspace.runSSHControlMasterCommandOverrideForTesting = { _ in }
        defer { Workspace.runSSHControlMasterCommandOverrideForTesting = priorCleanup }
        let localDirectory = "/Users/alice/development"
        let remoteDirectory = "/home/seepine/workspace"
        let sshCommand = "ssh seepine@192.168.5.20"
        let workspace = Workspace(
            workingDirectory: localDirectory,
            initialTerminalCommand: sshCommand
        )
        defer { workspace.teardownAllPanels(); workspace.teardownRemoteConnection() }
        let remotePanelId = try #require(workspace.focusedPanelId)
        #expect(workspace.updatePanelDirectory(panelId: remotePanelId, directory: localDirectory))
        workspace.configureRemoteConnection(sshRemoteConfiguration(command: sshCommand), autoConnect: false)
        workspace.updatePanelGitBranch(panelId: remotePanelId, branch: "remote-main", isDirty: false)
        let paneId = try #require(workspace.bonsplitController.focusedPaneId)
        _ = try #require(workspace.newTerminalSurface(inPane: paneId, focus: true, suppressWorkspaceRemoteStartupCommand: true))
        workspace.focusPanel(remotePanelId)
        var snapshot = workspace.sessionSnapshot(includeScrollback: false)
        let snapshotIndex = try #require(snapshot.panels.firstIndex { $0.id == remotePanelId })
        snapshot.panels[snapshotIndex].directory = remoteDirectory
        snapshot.panels[snapshotIndex].directoryIsTrustedRemoteReport = nil
        let restored = Workspace()
        defer { restored.teardownAllPanels(); restored.teardownRemoteConnection() }
        let restoredPanelId = try #require(restored.restoreSessionSnapshot(snapshot)[remotePanelId])
        #expect(restored.focusedPanelId == restoredPanelId)
        #expect(restored.panelDirectories[restoredPanelId] == remoteDirectory)
        #expect(restored.reportedPanelDirectory(panelId: restoredPanelId) == nil)
        #expect(restored.presentedCurrentDirectory == nil)
        #expect(restored.sidebarFilesystemDirectoriesInDisplayOrder() == [])
        #expect(restored.sidebarGitBranchesInDisplayOrder().isEmpty && restored.gitBranch == nil)
        #expect(!restored.updatePanelDirectory(panelId: restoredPanelId, directory: remoteDirectory))
        #expect(restored.reportedPanelDirectory(panelId: restoredPanelId) == nil)
        restored.updateRemotePanelDirectory(panelId: restoredPanelId, directory: remoteDirectory)
        #expect(restored.reportedPanelDirectory(panelId: restoredPanelId) == remoteDirectory)
        #expect(restored.reportedPanelGitBranch(panelId: restoredPanelId) == nil)
        #expect(restored.presentedCurrentDirectory == remoteDirectory)
    }

    private func sshRemoteConfiguration(command: String) -> WorkspaceRemoteConfiguration {
        WorkspaceRemoteConfiguration(
            destination: "seepine@192.168.5.20",
            port: nil,
            identityFile: nil,
            sshOptions: [],
            localProxyPort: nil,
            relayPort: 64007,
            relayID: "relay-\(UUID().uuidString)",
            relayToken: String(repeating: "a", count: 64),
            localSocketPath: "/tmp/bmux-issue-7268-\(UUID().uuidString).sock",
            terminalStartupCommand: command
        )
    }
}
