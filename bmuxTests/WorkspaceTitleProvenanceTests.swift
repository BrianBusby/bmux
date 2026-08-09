import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Behavior tests for custom-title provenance: auto-naming writes must never
/// overwrite user-set titles, clearing must reset provenance, and provenance
/// must round-trip through session snapshots (with legacy snapshots that
/// predate provenance decoding).
@MainActor
@Suite struct WorkspaceTitleProvenanceTests {

    // MARK: - Workspace titles

    @Test func autoWriteOnUntitledWorkspaceLands() {
        let workspace = Workspace(title: "Terminal")
        let applied = workspace.setCustomTitle("Fix auth bug", source: .autoPrompt)
        #expect(applied)
        #expect(workspace.title == "Fix auth bug")
        #expect(workspace.customTitle == "Fix auth bug")
        #expect(workspace.effectiveCustomTitleSource == .autoPrompt)
    }

    @Test func autoWriteOverUserTitleIsRejected() {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("My Project")
        let applied = workspace.setCustomTitle("Fix auth bug", source: .autoPrompt)
        #expect(!applied)
        #expect(workspace.title == "My Project")
        #expect(workspace.effectiveCustomTitleSource == .user)
    }

    @Test func userWriteOverAutoTitleLandsAndClaimsOwnership() {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("Fix auth bug", source: .autoPrompt)
        let applied = workspace.setCustomTitle("Release prep")
        #expect(applied)
        #expect(workspace.title == "Release prep")
        #expect(workspace.effectiveCustomTitleSource == .user)
        // The workspace is now user-owned: further auto writes must be rejected.
        #expect(!workspace.setCustomTitle("Something else", source: .autoSummary))
    }

    @Test func summaryTitleCanRefinePromptTitle() {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("Fix auth bug", source: .autoPrompt)
        let applied = workspace.setCustomTitle("Debug login flow", source: .autoSummary)
        #expect(applied)
        #expect(workspace.title == "Debug login flow")
        #expect(workspace.effectiveCustomTitleSource == .autoSummary)
    }

    @Test func newPromptCanReplacePreviousSummaryTitle() {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("Debug login flow", source: .autoSummary)
        let applied = workspace.setCustomTitle("Fix workspace titles", source: .autoPrompt)
        #expect(applied)
        #expect(workspace.title == "Fix workspace titles")
        #expect(workspace.effectiveCustomTitleSource == .autoPrompt)
    }

    @Test func autoWriteNeverClears() {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("Fix auth bug", source: .autoPrompt)
        #expect(!workspace.setCustomTitle(nil, source: .autoPrompt))
        #expect(!workspace.setCustomTitle("   ", source: .autoSummary))
        #expect(workspace.title == "Fix auth bug")
    }

    @Test func clearingUserTitleRevertsToProcessTitleAndAllowsAutoWrite() {
        let workspace = Workspace(title: "Terminal")
        workspace.applyProcessTitle("zsh")
        workspace.setCustomTitle("My Project")
        workspace.setCustomTitle(nil)
        #expect(workspace.title == "zsh")
        #expect(workspace.customTitle == nil)
        #expect(workspace.effectiveCustomTitleSource == nil)
        #expect(workspace.setCustomTitle("Fix auth bug", source: .autoPrompt))
        #expect(workspace.effectiveCustomTitleSource == .autoPrompt)
    }

    @Test func carriedTitleWithoutProvenanceIsNotTreatedAsUserOwned() {
        let workspace = Workspace(title: "Terminal")
        // Simulate a custom title that arrived without provenance (legacy
        // restore, carried panel move): direct assignment bypasses the setter.
        workspace.customTitle = "Carried Title"
        #expect(workspace.effectiveCustomTitleSource == .user)
        #expect(!workspace.setCustomTitle("Fix auth bug", source: .autoPrompt))
        #expect(workspace.customTitle == "Carried Title")
    }

    @Test func generatedAgentSeedTitleIsAutoReplaceableEvenWithUserProvenance() {
        let workspace = Workspace(
            title: "bmux (Codex)",
            workingDirectory: "/Users/example/repos/bmux"
        )
        workspace.setCustomTitle("bmux (Codex)")

        #expect(workspace.effectiveCustomTitleSource == .agentSeed)
        #expect(workspace.setCustomTitle("Fix workspace titles", source: .autoPrompt))
        #expect(workspace.title == "Fix workspace titles")
        #expect(workspace.customTitle == "Fix workspace titles")
        #expect(workspace.customTitleSource == .autoPrompt)
    }

    @Test func generatedAgentSeedTitleIsAutoReplaceableWithoutRecordedProvenance() {
        let workspace = Workspace(
            title: "bmux (Codex)",
            workingDirectory: "/Users/example/repos/bmux"
        )
        workspace.customTitle = "bmux (Codex)"

        #expect(workspace.effectiveCustomTitleSource == .agentSeed)
        #expect(workspace.setCustomTitle("Fix workspace titles", source: .autoPrompt))
        #expect(workspace.title == "Fix workspace titles")
        #expect(workspace.customTitle == "Fix workspace titles")
        #expect(workspace.customTitleSource == .autoPrompt)
    }

    @Test func arbitraryAgentLookingUserTitleStillBlocksAutoWrite() {
        let workspace = Workspace(
            title: "Personal (Codex)",
            workingDirectory: "/Users/example/repos/bmux"
        )
        workspace.setCustomTitle("Personal (Codex)")

        #expect(workspace.effectiveCustomTitleSource == .user)
        #expect(!workspace.setCustomTitle("Fix workspace titles", source: .autoPrompt))
        #expect(workspace.title == "Personal (Codex)")
    }

    @Test func workspaceRenameTitleRejectsEmptyInputWithoutClearingExistingTitle() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)

        let applied = manager.renameWorkspaceTitle(tabId: workspace.id, title: "  My Project  ")
        #expect(applied.applied)
        #expect(workspace.customTitle == "My Project")
        #expect(workspace.effectiveCustomTitleSource == .user)

        let rejected = manager.renameWorkspaceTitle(tabId: workspace.id, title: "   ")
        #expect(!rejected.applied)
        #expect(rejected.rejectionReason == .emptyTitle)
        #expect(workspace.customTitle == "My Project")
        #expect(workspace.title == "My Project")
    }

    @Test func workspaceTitleEditCanTreatEmptyInputAsClear() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        workspace.applyProcessTitle("zsh")
        manager.renameWorkspaceTitle(tabId: workspace.id, title: "  My Project  ")

        let cleared = manager.commitWorkspaceTitleEdit(tabId: workspace.id, title: "   ")

        #expect(cleared.applied)
        #expect(workspace.customTitle == nil)
        #expect(workspace.effectiveCustomTitleSource == nil)
        #expect(workspace.title == "zsh")
    }

    @Test func workspaceTitleEditRejectsMissingWorkspaceWithoutMutatingExistingTitles() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        manager.renameWorkspaceTitle(tabId: workspace.id, title: "Stable")

        let rejected = manager.commitWorkspaceTitleEdit(tabId: UUID(), title: "Other")

        #expect(!rejected.applied)
        #expect(rejected.rejectionReason == .targetMissing)
        #expect(workspace.customTitle == "Stable")
    }

    @Test func workspaceTitleEditPostsNotificationForAppliedDisplayTitleChange() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        var notifications: [Notification] = []
        let observer = NotificationCenter.default.addObserver(
            forName: .workspaceTitleDidChange,
            object: manager,
            queue: nil
        ) { notification in
            notifications.append(notification)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let applied = manager.commitWorkspaceTitleEdit(tabId: workspace.id, title: "  Shared Path  ")

        #expect(applied.applied)
        #expect(workspace.customTitle == "Shared Path")
        #expect(notifications.count == 1)
        #expect(notifications.first?.userInfo?[GhosttyNotificationKey.tabId] as? UUID == workspace.id)
    }

    // MARK: - Panel titles

    @Test func panelProvenanceMirrorsWorkspaceRules() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panelId = try #require(workspace.newTerminalSurface(inPane: pane, focus: true)?.id)

        #expect(workspace.setPanelCustomTitle(panelId: panelId, title: "Fix auth bug", source: .autoPrompt))
        #expect(workspace.panelCustomTitles[panelId] == "Fix auth bug")
        #expect(workspace.panelCustomTitleSources[panelId] == .autoPrompt)

        #expect(workspace.setPanelCustomTitle(panelId: panelId, title: "Debug login flow", source: .autoSummary))
        #expect(workspace.panelCustomTitleSources[panelId] == .autoSummary)

        // User rename wins and claims ownership.
        #expect(workspace.setPanelCustomTitle(panelId: panelId, title: "Build Pane"))
        #expect(workspace.panelCustomTitleSources[panelId] == .user)
        #expect(!workspace.setPanelCustomTitle(panelId: panelId, title: "Other", source: .autoPrompt))
        #expect(workspace.panelCustomTitles[panelId] == "Build Pane")

        // Clearing resets provenance and re-opens the panel to auto naming.
        #expect(workspace.setPanelCustomTitle(panelId: panelId, title: nil))
        #expect(workspace.panelCustomTitles[panelId] == nil)
        #expect(workspace.panelCustomTitleSources[panelId] == nil)
        #expect(workspace.setPanelCustomTitle(panelId: panelId, title: "Refreshed", source: .autoPrompt))
        #expect(workspace.panelCustomTitleSources[panelId] == .autoPrompt)
    }

    @Test func panelAutoWriteRejectedForCarriedTitleWithoutProvenance() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panelId = try #require(workspace.newTerminalSurface(inPane: pane, focus: true)?.id)

        // Simulate a carried title (move/respawn flows write the dictionary
        // directly when no provenance traveled with the title).
        workspace.panelCustomTitles[panelId] = "Carried Tab"
        #expect(!workspace.setPanelCustomTitle(panelId: panelId, title: "Other", source: .autoPrompt))
        #expect(workspace.panelCustomTitles[panelId] == "Carried Tab")
    }

    @Test func surfaceTitleActionTrimsRenameAndRejectsEmptyInput() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panelId = try #require(workspace.newTerminalSurface(inPane: pane, focus: true)?.id)
        let surfaceId = try #require(workspace.surfaceIdFromPanelId(panelId)?.uuid)

        let applied = workspace.renameSurfaceTitleForAction(
            surfaceId: surfaceId,
            title: "  Build Pane  "
        )

        #expect(applied.applied)
        #expect(workspace.panelCustomTitles[panelId] == "Build Pane")
        #expect(workspace.panelCustomTitleSources[panelId] == .user)

        let rejected = workspace.renameSurfaceTitleForAction(surfaceId: surfaceId, title: "   ")
        #expect(!rejected.applied)
        #expect(rejected.rejectionReason == .emptyTitle)
        #expect(workspace.panelCustomTitles[panelId] == "Build Pane")
    }

    @Test func surfaceTitleEditCanTreatEmptyInputAsClear() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panelId = try #require(workspace.newTerminalSurface(inPane: pane, focus: true)?.id)

        workspace.renameSurfaceTitleForAction(surfaceId: panelId, title: "Review")
        let cleared = workspace.commitSurfaceTitleEditForAction(surfaceId: panelId, title: "   ")

        #expect(cleared.applied)
        #expect(workspace.panelCustomTitles[panelId] == nil)
        #expect(workspace.panelCustomTitleSources[panelId] == nil)
    }

    @Test func surfaceTitleActionRejectsMissingSurfaceWithoutMutatingExistingTitles() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let panelId = try #require(workspace.newTerminalSurface(inPane: pane, focus: true)?.id)
        workspace.renameSurfaceTitleForAction(surfaceId: panelId, title: "Stable")

        let rejected = workspace.commitSurfaceTitleEditForAction(surfaceId: UUID(), title: "Other")

        #expect(!rejected.applied)
        #expect(rejected.rejectionReason == .targetMissing)
        #expect(workspace.panelCustomTitles[panelId] == "Stable")
    }

    // MARK: - Snapshot round-trip

    @Test func workspaceSnapshotRoundTripPreservesProvenance() throws {
        var snapshot = SessionWorkspaceSnapshot(
            processTitle: "zsh",
            customTitle: "Fix auth bug",
            customTitleSource: .autoSummary,
            customDescription: nil,
            customColor: nil,
            isPinned: false,
            currentDirectory: "/tmp",
            focusedPanelId: nil,
            layout: .pane(SessionPaneLayoutSnapshot(panelIds: [], selectedPanelId: nil)),
            panels: [],
            statusEntries: [],
            logEntries: []
        )
        let decoded = try JSONDecoder().decode(
            SessionWorkspaceSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        #expect(decoded.customTitleSource == .autoSummary)

        let legacyAutoData = try #require(
            #"{"processTitle":"zsh","customTitle":"Fix auth bug","customTitleSource":"auto","customDescription":null,"customColor":null,"isPinned":false,"terminalScrollBarHidden":null,"currentDirectory":"/tmp","focusedPanelId":null,"layout":{"type":"pane","pane":{"panelIds":[]}},"panels":[],"statusEntries":[],"logEntries":[]}"#.data(using: .utf8)
        )
        let legacyAutoDecoded = try JSONDecoder().decode(
            SessionWorkspaceSnapshot.self,
            from: legacyAutoData
        )
        #expect(legacyAutoDecoded.customTitleSource == .auto)

        // Legacy shape: encoding a nil source omits the key, which is exactly
        // what snapshots persisted before provenance look like on disk.
        snapshot.customTitleSource = nil
        let legacyDecoded = try JSONDecoder().decode(
            SessionWorkspaceSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        #expect(legacyDecoded.customTitleSource == nil)

        // Restore semantics: absent provenance restores as undecided and is
        // treated as non-user ownership for future auto titles.
        let workspace = Workspace(title: "Terminal")
        if let source = legacyDecoded.customTitleSource {
            workspace.setCustomTitle(legacyDecoded.customTitle, source: source)
        } else if legacyDecoded.customTitle != nil {
            workspace.setCustomTitle(legacyDecoded.customTitle, source: .auto)
        } else {
            workspace.setCustomTitle(nil)
        }
        #expect(workspace.effectiveCustomTitleSource == .auto)
    }
}
