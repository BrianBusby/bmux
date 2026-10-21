import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct WorkspaceArchiveTests {
    @Test
    func archiveTableIsRestoredForExistingSchema26WithoutIt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-archive-repair-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        _ = try ProvenanceSQLiteRepository(url: url,
            migrations: ProvenanceSQLiteRepository.migrations.filter { $0.version <= 25 })
        let database = try ProvenanceSQLiteDatabase(url: url)
        try database.execute("UPDATE provenance_metadata SET value = '26' WHERE key = 'schema_version'")
        try database.setUserVersion(26)

        let reopened = try ProvenanceSQLiteRepository(url: url)
        #expect(try await reopened.archivedWorkspaces(.init()).records.isEmpty)
        #expect(try await reopened.schemaVersion() == 27)
    }

    @Test
    func schema27PreservesExistingArchivedWorkspace() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-archive-upgrade-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let older = try ProvenanceSQLiteRepository(url: url,
            migrations: ProvenanceSQLiteRepository.migrations.filter { $0.version <= 26 })
        let record = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Maple Street Roof Inspection",
            createdAt: nil, closedAt: Date(timeIntervalSince1970: 1_800_000_000),
            lastActivityAt: nil, displayAtClose: nil, colorHex: nil, coverageCode: nil)
        try await older.recordArchivedWorkspace(record)

        let upgraded = try ProvenanceSQLiteRepository(url: url)
        #expect(try await upgraded.archivedWorkspaces(.init()).records == [record])
        #expect(try await upgraded.schemaVersion() == 27)
    }

    @Test
    func workspaceSessionsUseWorkEventsRatherThanMetadataRefreshForActivity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-sessions-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for (id, workspaceID, start, metadataUpdate) in [
            ("session-a", "stable-a", 100.0, 900.0),
            ("session-b", "stable-a", 200.0, 300.0),
            ("session-other", "stable-b", 400.0, 400.0),
        ] {
            let session = ProvenanceSessionRecord(
                id: id, agentKind: "codex", workspaceID: workspaceID, status: "completed",
                startedAt: base.addingTimeInterval(start),
                updatedAt: base.addingTimeInterval(metadataUpdate)
            )
            try await repository.appendEvent(ProvenanceEvent(
                eventType: .sessionObserved, timestamp: session.updatedAt,
                sessionID: id, source: .observed, confidence: .high,
                payload: ProvenanceEventPayload(session: session)
            ))
        }
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "prompt-a", sessionID: "session-a", provider: "codex", text: "Inspect the roof photos",
            submittedAt: base.addingTimeInterval(250), source: .observed, confidence: .high
        )
        try await repository.appendEvent(ProvenanceEvent(
            eventType: .codingAgentPromptSubmitted, timestamp: prompt.submittedAt,
            sessionID: prompt.sessionID, source: .observed, confidence: .high,
            payload: ProvenanceEventPayload(codingAgentPrompt: prompt)
        ))

        let first = try await repository.workspaceSessions(.init(workspaceID: "stable-a", limit: 1))
        #expect(first.sessions.map(\.id) == ["session-a"])
        #expect(first.sessions.first?.lastActivityAt == prompt.submittedAt)
        #expect(first.partialCoverage)
        let second = try await repository.workspaceSessions(.init(
            workspaceID: "stable-a", limit: 1, cursor: first.nextCursor
        ))
        #expect(second.sessions.map(\.id) == ["session-b"])
        #expect(second.nextCursor == nil)
        _ = try await repository.rebuildProjectionsFromEventLedger()
        #expect(try await repository.workspaceSessions(.init(workspaceID: "stable-a")).sessions.map(\.id)
                == ["session-a", "session-b"])
    }

    @Test
    func archiveSurvivesClientReopenAndPaginatesByStableIdentity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-archive-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let first = try ProvenanceSQLiteRepository(url: url)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let older = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Maple Street Roof Inspection", createdAt: now.addingTimeInterval(-3600),
            closedAt: now, lastActivityAt: now.addingTimeInterval(-60), displayAtClose: nil,
            colorHex: "#3B6FD6", coverageCode: "codex_only"
        )
        let newer = ProvenanceArchivedWorkspaceRecord(
            id: "stable-b", title: "Warehouse Safety Checklist", createdAt: now,
            closedAt: now.addingTimeInterval(60), lastActivityAt: now, displayAtClose: nil,
            colorHex: nil, coverageCode: nil
        )
        try await first.recordArchivedWorkspace(older)
        try await first.recordArchivedWorkspace(newer)
        #expect(try await first.storageSummary().eventCount == 0)
        _ = try await first.rebuildProjectionsFromEventLedger()
        let page1 = try await first.archivedWorkspaces(.init(limit: 1))
        #expect(page1.records == [newer])
        let cursor = try #require(page1.nextCursor)
        let page2 = try await first.archivedWorkspaces(.init(limit: 1, cursor: cursor))
        #expect(page2.records == [older])
        #expect(page2.nextCursor == nil)

        let reopenedClient = try ProvenanceSQLiteRepository(url: url)
        let afterRestore = try await reopenedClient.archivedWorkspaces(.init())
        #expect(afterRestore.records == [newer, older])
        #expect(try await reopenedClient.schemaVersion() == 27)
    }

    @Test
    func laterClosureReplacesSameLogicalWorkspaceWithoutDuplicate() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-archive-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let first = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Roof Inspection", createdAt: nil,
            closedAt: Date(timeIntervalSince1970: 100), lastActivityAt: nil,
            displayAtClose: nil, colorHex: nil, coverageCode: nil
        )
        let second = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Roof Inspection Follow-up", createdAt: nil,
            closedAt: Date(timeIntervalSince1970: 200), lastActivityAt: nil,
            displayAtClose: nil, colorHex: nil, coverageCode: nil
        )
        try await repository.recordArchivedWorkspace(first)
        try await repository.recordArchivedWorkspace(second)
        try await repository.recordArchivedWorkspace(first)
        #expect(try await repository.storageSummary().eventCount == 0)
        #expect(try await repository.archivedWorkspaces(.init()).records == [second])
        try await repository.clearArchivedWorkspaces(at: Date(timeIntervalSince1970: 250))
        #expect(try await repository.archivedWorkspaces(.init()).records.isEmpty)
        #expect(try await repository.storageSummary().eventCount == 0)
        let delayedOldClose = ProvenanceArchivedWorkspaceRecord(
            id: "stable-b", title: "Delayed old closure", createdAt: nil,
            closedAt: Date(timeIntervalSince1970: 150), lastActivityAt: nil,
            displayAtClose: nil, colorHex: nil, coverageCode: nil
        )
        try await repository.recordArchivedWorkspace(delayedOldClose)
        #expect(try await repository.archivedWorkspaces(.init()).records.isEmpty)
        _ = try await repository.rebuildProjectionsFromEventLedger()
        #expect(try await repository.archivedWorkspaces(.init()).records.isEmpty)
        let reclosed = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Roof Inspection Follow-up", createdAt: nil,
            closedAt: Date(timeIntervalSince1970: 300), lastActivityAt: nil,
            displayAtClose: nil, colorHex: nil, coverageCode: nil
        )
        try await repository.recordArchivedWorkspace(reclosed)
        _ = try await repository.rebuildProjectionsFromEventLedger()
        #expect(try await repository.archivedWorkspaces(.init()).records == [reclosed])
    }
}
