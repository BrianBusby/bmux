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
struct WorkspaceArchiveCaptureTests {
    @MainActor
    @Test
    func closeWritesRecoveryIdentityBeforeAsynchronousArchiveCompletes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-close-identity-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("provenance.sqlite")
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        let runtime = WorkProvenanceRuntime(
            observationService: nil,
            workspaceArchiveService: WorkProvenanceWorkspaceArchiveService(client: client),
            effectiveDatabaseURL: databaseURL,
            initialLifecycleState: .ready
        )
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        workspace.customTitle = "Maple Street Roof Inspection"
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)

        runtime.recordWorkspaceClosure(workspace, at: closedAt)

        let recordURL = directory.appendingPathComponent("explorer-close-journal", isDirectory: true)
            .appendingPathComponent("\(workspace.stableId.uuidString).json")
        let data = try Data(contentsOf: recordURL)
        let record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(record["stableID"] as? String == workspace.stableId.uuidString)
        #expect(record["title"] as? String == "Maple Street Roof Inspection")
        #expect(record["closedAt"] as? TimeInterval == closedAt.timeIntervalSince1970)
    }

    @MainActor
    @Test
    func closedWindowArchivesEveryWorkspaceUnlessHistoryIsSuppressed() async throws {
        let originalAppDelegate = AppDelegate.shared
        let appDelegate = AppDelegate()
        AppDelegate.shared = appDelegate
        ClosedItemHistoryStore.shared.removeAll()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-closed-window-archive-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            ClosedItemHistoryStore.shared.removeAll()
            AppDelegate.shared = originalAppDelegate
        }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite")
        )
        let runtime = WorkProvenanceRuntime(
            observationService: nil,
            workspaceArchiveService: WorkProvenanceWorkspaceArchiveService(client: client),
            initialLifecycleState: .ready
        )
        let manager = TabManager()
        let first = try #require(manager.selectedWorkspace)
        let second = manager.addWorkspace()
        manager.workProvenanceRuntime = runtime
        let windowID = appDelegate.registerMainWindowContextForTesting(tabManager: manager)
        defer { appDelegate.unregisterMainWindowContextForTesting(windowId: windowID) }

        appDelegate.suppressClosedWindowHistoryForTesting(windowId: windowID)
        appDelegate.recordClosedWindowHistoryForTesting(windowId: windowID)
        await runtime.waitForArchiveTasks()
        #expect(try await client.archivedWorkspaces(.init()).records.isEmpty)

        appDelegate.recordClosedWindowHistoryForTesting(windowId: windowID)
        await runtime.waitForArchiveTasks()
        let ids = Set(try await client.archivedWorkspaces(.init()).records.map(\.id))
        #expect(ids == [first.stableId.uuidString, second.stableId.uuidString])
    }

    @Test
    func workspaceArchiveServiceRecordsStableIdentityWhenDisplayIsMissing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-workspace-archive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite")
        )
        let service = WorkProvenanceWorkspaceArchiveService(client: client)
        let stableID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try await service.recordClosure(
            stableWorkspaceID: stableID,
            title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600),
            closedAt: closedAt,
            colorHex: "#3B6FD6",
            lastRecordedStatusCode: nil
        )

        let records = try await client.archivedWorkspaces(.init()).records
        #expect(records.count == 1)
        #expect(records.first?.id == stableID.uuidString)
        #expect(records.first?.title == "Maple Street Roof Inspection")
        #expect(records.first?.lastActivityAt == nil)
    }

    @MainActor
    @Test
    func savedCloseSnapshotsRecoverMissingArchiveWithoutUndoingClear() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-workspace-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite")
        )
        let manager = TabManager()
        let first = try #require(manager.selectedWorkspace)
        first.customTitle = "Maple Street Roof Inspection"
        let second = manager.addWorkspace()
        second.customTitle = "Cedar Street Roof Inspection"
        let closedAt = Date().addingTimeInterval(10)
        let direct = ClosedItemHistoryRecord(closedAt: closedAt,
            entry: .workspace(ClosedWorkspaceHistoryEntry(workspaceId: first.id,
                windowId: nil, workspaceIndex: 0,
                snapshot: first.sessionSnapshot(includeScrollback: false))))
        let window = SessionWindowSnapshot(frame: nil, display: nil,
            tabManager: manager.sessionSnapshot(includeScrollback: false),
            sidebar: SessionSidebarSnapshot(isVisible: true, selection: .tabs, width: nil))
        let windowRecord = ClosedItemHistoryRecord(closedAt: closedAt.addingTimeInterval(-1),
            entry: .window(ClosedWindowHistoryEntry(snapshot: window)))
        let candidates = WorkspaceArchiveRecoveryCandidate.from(
            records: [windowRecord, direct], excluding: [])
        #expect(candidates.count == 2)
        #expect(candidates.first(where: { $0.stableID == first.stableId })?.closedAt == closedAt)
        #expect(WorkspaceArchiveRecoveryCandidate.from(
            records: [windowRecord, direct], excluding: [first.stableId]).map(\.stableID) ==
            [second.stableId])

        let service = WorkProvenanceWorkspaceArchiveService(client: client)
        try await service.recordClosure(stableWorkspaceID: second.stableId,
            title: second.customTitle ?? "Cedar Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600),
            closedAt: closedAt.addingTimeInterval(-1), colorHex: nil,
            lastRecordedStatusCode: nil)
        try await service.recoverClosures(candidates)
        let recovered = try await client.archivedWorkspaces(.init()).records
        #expect(Set(recovered.map(\.id)) == [first.stableId.uuidString, second.stableId.uuidString])
        #expect(recovered.first(where: { $0.id == first.stableId.uuidString })?.createdAt == nil)
        #expect(recovered.first(where: { $0.id == first.stableId.uuidString })?.title ==
            "Maple Street Roof Inspection")
        #expect(recovered.first(where: { $0.id == second.stableId.uuidString })?.createdAt ==
            closedAt.addingTimeInterval(-3600))

        try await service.clearExplorerHistory(at: closedAt.addingTimeInterval(1))
        let restartedService = WorkProvenanceWorkspaceArchiveService(client: client)
        try await restartedService.recoverClosures(candidates)
        #expect(try await client.archivedWorkspaces(.init()).records.isEmpty)
    }

    @MainActor
    @Test
    func recoveryReplacesOlderClosureForSameWorkspace() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-workspace-reclose-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"))
        let service = WorkProvenanceWorkspaceArchiveService(client: client)
        let stableID = UUID()
        let firstClose = Date(timeIntervalSince1970: 1_800_000_000)
        try await service.recordClosure(stableWorkspaceID: stableID,
            title: "Maple Street Roof Inspection", createdAt: firstClose.addingTimeInterval(-3600),
            closedAt: firstClose, colorHex: nil,
            lastRecordedStatusCode: "running")

        let laterClose = firstClose.addingTimeInterval(600)
        try await service.recoverClosures([WorkspaceArchiveRecoveryCandidate(
            stableID: stableID, title: "Maple Street Follow-up",
            closedAt: laterClose, colorHex: nil)])

        let record = try #require(await client.archivedWorkspaces(.init()).records.first)
        #expect(record.closedAt == laterClose)
        #expect(record.title == "Maple Street Follow-up")
        #expect(record.createdAt == firstClose.addingTimeInterval(-3600))
        #expect(record.lastRecordedStatusCode == nil)
    }

    @MainActor
    @Test
    func recoveryWaitsForPersistedRestoreRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-restore-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("recently-closed.json")
        let workspace = try #require(TabManager().selectedWorkspace)
        workspace.customTitle = "Maple Street Roof Inspection"
        let record = ClosedItemHistoryRecord(entry: .workspace(ClosedWorkspaceHistoryEntry(
            workspaceId: workspace.id, windowId: nil, workspaceIndex: 0,
            snapshot: workspace.sessionSnapshot(includeScrollback: false))))
        let writer = ClosedItemHistoryStore(fileURL: fileURL, loadPersisted: false,
            persistsRecordsSynchronously: true)
        writer.push(record)

        let reader = ClosedItemHistoryStore(fileURL: fileURL)
        let loaded = await reader.recordsAfterPersistedLoad()
        #expect(loaded.map(\.id) == [record.id])
        #expect(WorkspaceArchiveRecoveryCandidate.from(records: loaded, excluding: [])
            .map(\.stableID) == [workspace.stableId])
    }
}
