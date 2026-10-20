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
        await runtime.waitForBackgroundTasks()
        #expect(try await client.archivedWorkspaces(.init()).records.isEmpty)

        appDelegate.recordClosedWindowHistoryForTesting(windowId: windowID)
        await runtime.waitForBackgroundTasks()
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
            colorHex: "#3B6FD6"
        )

        let records = try await client.archivedWorkspaces(.init()).records
        #expect(records.count == 1)
        #expect(records.first?.id == stableID.uuidString)
        #expect(records.first?.title == "Maple Street Roof Inspection")
        #expect(records.first?.lastActivityAt == nil)
    }
}
