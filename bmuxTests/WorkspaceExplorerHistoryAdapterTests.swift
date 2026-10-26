import AppKit
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkspaceExplorerHistoryAdapterTests {
    @MainActor
    @Test
    func recoverableWindowWorkspaceRemainsLiveDuringContextRecovery() throws {
        _ = NSApplication.shared
        let appDelegate = AppDelegate()
        let registeredID = UUID()
        let recoveredID = UUID()
        let registeredWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let recoveredWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        registeredWindow.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(registeredID.uuidString)")
        recoveredWindow.identifier = NSUserInterfaceItemIdentifier("bmux.main.\(recoveredID.uuidString)")
        defer {
            appDelegate.unregisterMainWindowContextForTesting(windowId: registeredID)
            appDelegate.unregisterMainWindowContextForTesting(windowId: recoveredID)
            registeredWindow.orderOut(nil)
            recoveredWindow.orderOut(nil)
        }
        let registeredManager = TabManager()
        let recoveredManager = TabManager()
        appDelegate.registerMainWindow(
            registeredWindow, windowId: registeredID, tabManager: registeredManager,
            sidebarState: SidebarState(), sidebarSelectionState: SidebarSelectionState(),
            fileExplorerState: FileExplorerState()
        )
        appDelegate.registerMainWindow(
            recoveredWindow, windowId: recoveredID, tabManager: recoveredManager,
            sidebarState: SidebarState(), sidebarSelectionState: SidebarSelectionState(),
            fileExplorerState: FileExplorerState()
        )
        let recoveredWorkspace = try #require(recoveredManager.selectedWorkspace)

        appDelegate.unregisterMainWindowContextForTesting(windowId: recoveredID)
        #expect(appDelegate.recoverableMainWindowRoutes().contains { $0.windowId == recoveredID })
        #expect(appDelegate.workspaceExplorerLiveWorkspaces().contains { $0.stableId == recoveredWorkspace.stableId })
    }

    @MainActor
    @Test
    func liveStatusRequiresMatchingAgentProcessIdentity() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(workspace.focusedPanelId)
        workspace.agentPIDKeysByPanelId[panelID] = ["codex"]
        workspace.agentPIDs["codex"] = getpid()
        workspace.agentLifecycleStatesByPanelId[panelID] = ["codex": .needsInput]
        #expect(WorkspaceExplorerStatus.verified(of: workspace) == .disconnected)
        workspace.agentPIDProcessIdentitiesByKey["codex"] = Workspace.agentPIDProcessIdentity(pid: getpid())
        #expect(WorkspaceExplorerStatus.verified(of: workspace) == .needsInput)
        workspace.agentLifecycleStatesByPanelId[panelID] = ["codex": .running]
        #expect(WorkspaceExplorerStatus.verified(of: workspace) == .running)
    }

    @MainActor
    @Test
    func statusMonitorPublishesVerifiedLifecycleChanges() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(workspace.focusedPanelId)
        workspace.agentPIDKeysByPanelId[panelID] = ["codex"]
        workspace.agentPIDs["codex"] = getpid()
        workspace.agentPIDProcessIdentitiesByKey["codex"] = Workspace.agentPIDProcessIdentity(pid: getpid())
        let monitor = WorkspaceExplorerLiveStatusMonitor(workspaces: { [workspace] })
        var received: [WorkspaceExplorerStatus] = []
        monitor.start { _, status in received.append(status) }
        workspace.agentLifecycleStatesByPanelId[panelID] = ["codex": .needsInput]
        #expect(received.last == .needsInput)
        workspace.agentLifecycleStatesByPanelId[panelID] = ["codex": .running]
        #expect(received.last == .running)
    }

    @MainActor
    @Test
    func statusMonitorUpdatesWhenVerifiedProcessIdentityChanges() async throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelID = try #require(workspace.focusedPanelId)
        workspace.agentPIDKeysByPanelId[panelID] = ["codex"]
        workspace.agentPIDs["codex"] = getpid()
        workspace.agentPIDProcessIdentitiesByKey["codex"] = Workspace.agentPIDProcessIdentity(pid: getpid())
        workspace.agentLifecycleStatesByPanelId[panelID] = ["codex": .running]
        let monitor = WorkspaceExplorerLiveStatusMonitor(workspaces: { [workspace] })
        var received: [WorkspaceExplorerStatus] = []
        monitor.start { _, status in received.append(status) }

        workspace.agentPIDProcessIdentitiesByKey.removeValue(forKey: "codex")
        for _ in 0..<100 where received.last != .disconnected { await Task.yield() }
        #expect(received.last == .disconnected)

        workspace.agentPIDProcessIdentitiesByKey["codex"] = Workspace.agentPIDProcessIdentity(pid: getpid())
        for _ in 0..<100 where received.last != .running { await Task.yield() }
        #expect(received.last == .running)
    }

#if DEBUG
    @MainActor
    @Test
    func dogfoodFixtureKeepsHistoryWhenReopenedAndClearsOnlyArchiveCards() throws {
        let fixture = WorkspaceExplorerDogfoodFixture()
        let initial = fixture.load()
        #expect(initial.items.filter(\.isOpen).count == 1)
        #expect(initial.items.filter { !$0.isOpen }.count == 42)
        let closed = try #require(initial.items.first { $0.title == "Inspect flashing details" })
        let stableID = try #require(UUID(uuidString: closed.id))
        #expect(fixture.sessions(stableID).sessions.count == 1)
        #expect(fixture.reopen(stableID))
        let reopened = fixture.load().items.filter { $0.id == closed.id }
        #expect(reopened.count == 1)
        #expect(reopened[0].isOpen)
        #expect(reopened[0].archive != nil)
        fixture.clear()
        let cleared = fixture.load()
        #expect(cleared.items.filter { !$0.isOpen }.isEmpty)
        #expect(cleared.items.contains { $0.id == closed.id && $0.isOpen })
    }
#endif

    @Test
    func reopenedWorkspaceAppearsOnceAndKeepsItsArchive() {
        let stableID = UUID()
        let runtimeID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let archive = archivedRecord(id: stableID, closedAt: closedAt)
        let live = WorkspaceExplorerLiveWorkspace(
            stableID: stableID,
            runtimeID: runtimeID,
            title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600),
            colorHex: "#3B6FD6",
            display: nil,
            lastActivityAt: closedAt.addingTimeInterval(60)
        )

        let items = WorkspaceExplorerHistoryAdapter().join(
            live: [live], archived: [archive], eligibilityByID: [:]
        )

        #expect(items.count == 1)
        #expect(items[0].id == stableID.uuidString)
        #expect(items[0].isOpen)
        #expect(items[0].closedAt == nil)
        #expect(items[0].archive == archive)
        #expect(items[0].liveWorkspaceID == runtimeID)
        #expect(items[0].reopenEligibility == .unavailable(.alreadyOpen))
    }

    @Test
    func reopenedWorkspaceKeepsArchivedActivityUntilNewEvidenceArrives() {
        let stableID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let archive = archivedRecord(id: stableID, closedAt: closedAt)
        let live = WorkspaceExplorerLiveWorkspace(
            stableID: stableID,
            runtimeID: UUID(),
            title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(60),
            colorHex: nil,
            display: nil,
            lastActivityAt: nil
        )

        let items = WorkspaceExplorerHistoryAdapter().join(
            live: [live], archived: [archive], eligibilityByID: [:]
        )

        #expect(items[0].lastActivityAt == archive.lastActivityAt)
        #expect(items[0].createdAt == archive.createdAt)
    }

    @Test
    func reopenedWorkspaceKeepsArchivedProjectWhenLiveDisplayIsUnavailable() {
        let stableID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let archivedDisplay = ProvenanceWorkspaceDisplayRecord(
            id: "display-at-close", workspaceID: stableID.uuidString,
            projectLinks: [.init(id: "maple-roof", title: "Maple Street Roof Inspection")],
            observedAt: closedAt, updatedAt: closedAt)
        let archive = ProvenanceArchivedWorkspaceRecord(
            id: stableID.uuidString, title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600), closedAt: closedAt,
            lastActivityAt: closedAt, displayAtClose: archivedDisplay,
            colorHex: nil, coverageCode: nil)
        let live = WorkspaceExplorerLiveWorkspace(
            stableID: stableID, runtimeID: UUID(), title: archive.title,
            createdAt: closedAt, colorHex: nil, display: nil, lastActivityAt: nil)

        let items = WorkspaceExplorerHistoryAdapter().join(
            live: [live], archived: [archive], eligibilityByID: [:])
        let catalog = WorkspaceExplorerCatalog(.init(items: items,
            archiveAvailability: .available, partialLiveActivity: true))

        #expect(items.count == 1)
        #expect(items[0].display?.projectLinks.map(\.id) == ["maple-roof"])
        #expect(catalog.workspaces[0].projectIDs == ["maple-roof"])
    }

    @Test
    func closedWorkspaceRetainsSnapshotAndRestoreEligibility() {
        let stableID = UUID()
        let restoreRecordID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let archive = archivedRecord(id: stableID, closedAt: closedAt)

        let items = WorkspaceExplorerHistoryAdapter().join(
            live: [],
            archived: [archive],
            eligibilityByID: [stableID: .eligible(recordID: restoreRecordID)]
        )

        #expect(items.count == 1)
        #expect(!items[0].isOpen)
        #expect(items[0].closedAt == closedAt)
        #expect(items[0].reopenEligibility == .eligible(recordID: restoreRecordID))
    }

    @MainActor
    @Test
    func unavailableArchiveStillReturnsOpenWorkspaces() async throws {
        let appDelegate = AppDelegate()
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let windowID = appDelegate.registerMainWindowContextForTesting(tabManager: manager)
        defer { appDelegate.unregisterMainWindowContextForTesting(windowId: windowID) }

        let result = try await appDelegate.loadWorkspaceExplorerHistory()

        #expect(result.archiveAvailability == .unavailable)
        #expect(result.items.contains(where: { $0.id == workspace.stableId.uuidString && $0.isOpen }))
        #expect(result.partialLiveActivity)
    }

    @MainActor
    @Test
    func recoveryFailureDoesNotBlockLiveExplorerSnapshot() async throws {
        struct RecoveryFailure: Error {}
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-explorer-recovery-failure-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"))
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        var recoveryCalled = false
        let service = WorkspaceExplorerHistoryService(
            archiveService: WorkProvenanceWorkspaceArchiveService(client: client),
            recoverArchive: {
                recoveryCalled = true
                throw RecoveryFailure()
            },
            tabManagers: { [manager] },
            activeWorkspaceID: { workspace.stableId.uuidString },
            restoreRecords: { [:] },
            reopenEligibility: { _, _, _ in .unavailable(.noRestoreSnapshot) })

        let result = try await service.load()

        #expect(result.archiveAvailability == .unavailable)
        #expect(recoveryCalled)
        #expect(!result.liveMetadataPending)
        #expect(result.items.contains { $0.id == workspace.stableId.uuidString && $0.isOpen })
    }

    @MainActor
    @Test
    func historyServiceProvidesSeparateLiveAndArchiveSnapshots() async throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let service = WorkspaceExplorerHistoryService(
            archiveService: nil,
            tabManagers: { [manager, manager] },
            activeWorkspaceID: { workspace.stableId.uuidString },
            restoreRecords: { [:] },
            reopenEligibility: { _, _, _ in .unavailable(.noRestoreSnapshot) })

        let presence = service.presenceSnapshot()
        #expect(presence.items.map(\.id) == [workspace.stableId.uuidString])
        #expect(presence.items[0].isOpen)
        #expect(presence.archiveAvailability == .unavailable)
        #expect(presence.partialLiveActivity)
        #expect(presence.liveMetadataPending)
        let live = try await service.liveSnapshot()
        #expect(live.workspaces.map(\.stableID) == [workspace.stableId])
        #expect(live.partialActivity)
        let archive = try await service.retainedSnapshot()
        let result = service.combine(live: live, archived: archive)
        #expect(!result.liveMetadataPending)
        #expect(result.items.count == 1)
        #expect(result.items[0].isOpen)
        #expect(result.archiveAvailability == .unavailable)
        #expect(result.activeWorkspaceID == workspace.stableId.uuidString)
    }

    @MainActor
    @Test
    func explicitReopenUsesStableIdentityAndConsumesRestoreRecord() throws {
        let originalAppDelegate = AppDelegate.shared
        let appDelegate = AppDelegate()
        AppDelegate.shared = appDelegate
        ClosedItemHistoryStore.shared.removeAll()
        defer {
            ClosedItemHistoryStore.shared.removeAll()
            AppDelegate.shared = originalAppDelegate
        }
        let manager = TabManager()
        _ = try #require(manager.selectedWorkspace)
        let workspace = manager.addWorkspace()
        let stableID = workspace.stableId
        let windowID = appDelegate.registerMainWindowContextForTesting(tabManager: manager)
        defer { appDelegate.unregisterMainWindowContextForTesting(windowId: windowID) }

        manager.closeWorkspace(workspace)
        guard case .eligible = appDelegate.workspaceExplorerReopenEligibility(stableID: stableID) else {
            Issue.record("The closed workspace should have a restorable snapshot")
            return
        }
        #expect(appDelegate.reopenWorkspaceExplorerHistory(stableID: stableID, preferredTabManager: manager))
        #expect(manager.tabs.filter { $0.stableId == stableID }.count == 1)
        #expect(ClosedItemHistoryStore.shared.workspaceRestoreRecord(stableId: stableID) == nil)
        #expect(appDelegate.workspaceExplorerReopenEligibility(stableID: stableID) == .unavailable(.alreadyOpen))
    }

    @MainActor
    @Test
    func missingDirectoryKeepsHistoryButDisablesReopen() throws {
        let originalAppDelegate = AppDelegate.shared
        let appDelegate = AppDelegate()
        AppDelegate.shared = appDelegate
        ClosedItemHistoryStore.shared.removeAll()
        defer {
            ClosedItemHistoryStore.shared.removeAll()
            AppDelegate.shared = originalAppDelegate
        }
        let manager = TabManager()
        _ = try #require(manager.selectedWorkspace)
        let workspace = manager.addWorkspace()
        let stableID = workspace.stableId
        workspace.currentDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("removed-worktree-\(UUID().uuidString)").path
        let windowID = appDelegate.registerMainWindowContextForTesting(tabManager: manager)
        defer { appDelegate.unregisterMainWindowContextForTesting(windowId: windowID) }

        manager.closeWorkspace(workspace)
        #expect(appDelegate.workspaceExplorerReopenEligibility(stableID: stableID) == .unavailable(.directoryRemoved))
        #expect(!appDelegate.reopenWorkspaceExplorerHistory(stableID: stableID, preferredTabManager: manager))
        #expect(ClosedItemHistoryStore.shared.workspaceRestoreRecord(stableId: stableID) != nil)
    }

    @MainActor
    @Test
    func explorerRestoreSnapshotDoesNotCarryAgentOrTmuxStartup() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        var snapshot = workspace.sessionSnapshot(includeScrollback: false)
        let terminalIndex = try #require(snapshot.panels.firstIndex(where: { $0.terminal != nil }))
        snapshot.panels[terminalIndex].terminal?.tmuxStartCommand = "echo should-not-run"
        snapshot.panels[terminalIndex].terminal?.wasAgentRunning = true
        let entry = ClosedWorkspaceHistoryEntry(
            workspaceId: workspace.id,
            windowId: nil,
            workspaceIndex: 0,
            snapshot: snapshot
        )

        let safe = try #require(entry.withoutAgentResume.snapshot.panels[terminalIndex].terminal)
        #expect(safe.tmuxStartCommand == nil)
        #expect(safe.agent == nil)
        #expect(safe.resumeBinding == nil)
        #expect(safe.hibernation == nil)
        #expect(safe.wasAgentRunning == false)
        #expect(entry.withoutAgentResume.snapshot.stableId == snapshot.stableId)
    }

    @Test
    func closeArchiveRetainsVerifiedStatusAsHistoricalContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-explorer-close-status-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"))
        let service = WorkProvenanceWorkspaceArchiveService(client: client)
        let stableID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try await service.recordClosure(stableWorkspaceID: stableID,
            title: "Maple Street Roof Inspection", createdAt: closedAt.addingTimeInterval(-3600),
            closedAt: closedAt, colorHex: nil,
            lastRecordedStatusCode: WorkspaceExplorerStatus.needsInput.archiveCode)
        let archived = try await service.archivedWorkspaces()
        let item = try #require(WorkspaceExplorerHistoryAdapter().join(
            live: [], archived: archived, eligibilityByID: [:]).first)

        #expect(archived.count == 1)
        #expect(archived[0].lastRecordedStatusCode == "needs_input")
        #expect(item.liveStatus == .closedHistorical)
        #expect(item.lastRecordedStatus == .needsInput)
    }

    @Test
    func sessionHistoryFromAnotherRunAppearsOnceWithReadOnlyIdentity() {
        let id = UUID()
        let activity = Date(timeIntervalSince1970: 1_800_000_000)
        let summary = ProvenanceWorkspaceHistorySummary(id: id.uuidString,
            firstSessionAt: activity.addingTimeInterval(-120), lastActivityAt: activity,
            sessionCount: 2, lastKnownDirectory: "/work/roof-inspection",
            lastKnownRepositoryID: "repository-roof")
        let adapter = WorkspaceExplorerHistoryAdapter()
        let items = adapter.join(live: [], archived: [], sessionWorkspaces: [summary], eligibilityByID: [:])
        #expect(items.count == 1)
        #expect(items[0].title == "roof-inspection")
        #expect(items[0].isSessionHistoryOnly)
        #expect(items[0].lastActivityAt == activity)
        #expect(WorkspaceExplorerCatalog(.init(items: items, archiveAvailability: .available,
            partialLiveActivity: false)).workspaces[0].repository == "repository-roof")
        #expect(items[0].reopenEligibility == .unavailable(.noRestoreSnapshot))

        let archive = archivedRecord(id: id, closedAt: activity.addingTimeInterval(60))
        let joined = adapter.join(live: [], archived: [archive], sessionWorkspaces: [summary],
            eligibilityByID: [:])
        #expect(joined.count == 1)
        #expect(joined[0].archive == archive)
        #expect(!joined[0].isSessionHistoryOnly)
    }

    @Test
    func repositoryNamesComeFromPersistedRemoteSlugs() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-explorer-repository-names-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"))
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(id: "repository-mobile",
            path: "/repos/.worktrees/mobile-feature", remoteSlug: "companycam/companycam-mobile",
            createdAt: timestamp, updatedAt: timestamp)
        let worktree = ProvenanceWorktreeRecord(id: "worktree-mobile",
            repositoryID: repository.id, path: repository.path, isDirty: false,
            status: "active", updatedAt: timestamp)
        for (type, payload) in [
            (ProvenanceEngineContracts.ProvenanceEventType.repositoryObserved,
                ProvenanceEngineContracts.ProvenanceEventPayload(repository: repository)),
            (ProvenanceEngineContracts.ProvenanceEventType.worktreeObserved,
                ProvenanceEngineContracts.ProvenanceEventPayload(worktree: worktree)),
        ] {
            _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(
                event: ProvenanceEngineContracts.ProvenanceEvent(
                eventType: type, timestamp: timestamp, source: .observed,
                confidence: .high, payload: payload)))
        }

        let names = try await WorkProvenanceWorkspaceArchiveService(client: client)
            .repositoryNames(for: [repository.id])
        #expect(names[repository.id] == "companycam-mobile")
    }

    private func archivedRecord(id: UUID, closedAt: Date) -> ProvenanceArchivedWorkspaceRecord {
        ProvenanceArchivedWorkspaceRecord(
            id: id.uuidString,
            title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600),
            closedAt: closedAt,
            lastActivityAt: closedAt.addingTimeInterval(-300),
            displayAtClose: nil,
            colorHex: "#3B6FD6",
            coverageCode: nil
        )
    }
}
