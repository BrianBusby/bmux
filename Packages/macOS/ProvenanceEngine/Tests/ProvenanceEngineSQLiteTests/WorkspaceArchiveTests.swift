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
        #expect(try await reopened.schemaVersion() == 28)
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
        #expect(try await upgraded.schemaVersion() == 28)
    }

    @Test
    func olderArchiveJSONWithoutStatusRemainsReadable() throws {
        let json = Data("""
            {"id":"stable-a","title":"Roof Inspection","createdAt":null,
             "closedAt":100,"lastActivityAt":null,"displayAtClose":null,
             "colorHex":null,"coverageCode":null}
            """.utf8)
        let record = try JSONDecoder().decode(ProvenanceArchivedWorkspaceRecord.self, from: json)
        #expect(record.lastRecordedStatusCode == nil)
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
        #expect(first.totalCount == 2)
        let second = try await repository.workspaceSessions(.init(
            workspaceID: "stable-a", limit: 1, cursor: first.nextCursor
        ))
        #expect(second.sessions.map(\.id) == ["session-b"])
        #expect(second.nextCursor == nil)
        #expect(second.totalCount == 2)
        #expect(try await repository.workspaceSessions(.init(workspaceID: "unknown")).totalCount == 0)
        _ = try await repository.rebuildProjectionsFromEventLedger()
        let rebuilt = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(rebuilt.sessions.map(\.id) == ["session-a", "session-b"])
        #expect(rebuilt.totalCount == 2)
    }

    @Test
    func workspaceHistoryFindsOtherRunsSessionsAndRespectsClearMarker() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-history-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = ProvenanceRepositoryRecord(id: "repository-b", path: "/work/other-run-b",
            createdAt: base, updatedAt: base)
        let worktree = ProvenanceWorktreeRecord(id: "worktree-b", repositoryID: repo.id,
            path: repo.path, isDirty: false, status: "active", updatedAt: base)
        try await repository.appendEvent(ProvenanceEvent(eventType: .repositoryObserved,
            timestamp: base, source: .observed, confidence: .high,
            payload: ProvenanceEventPayload(repository: repo)))
        try await repository.appendEvent(ProvenanceEvent(eventType: .worktreeObserved,
            timestamp: base, source: .observed, confidence: .high,
            payload: ProvenanceEventPayload(worktree: worktree)))
        for (id, workspaceID, start, update) in [
            ("session-old", "other-run-a", 100.0, 900.0),
            ("session-new", "other-run-b", 200.0, 200.0),
        ] {
            let session = ProvenanceSessionRecord(id: id, agentKind: "codex", workspaceID: workspaceID,
                worktreeID: workspaceID == "other-run-b" ? worktree.id : nil,
                cwd: "/work/" + workspaceID, status: "completed",
                startedAt: base.addingTimeInterval(start), updatedAt: base.addingTimeInterval(update))
            try await repository.appendEvent(ProvenanceEvent(eventType: .sessionObserved,
                timestamp: session.updatedAt, sessionID: id, source: .observed,
                confidence: .high, payload: ProvenanceEventPayload(session: session)))
        }
        let display = ProvenanceWorkspaceDisplayRecord(id: "display-other-run-b",
            workspaceID: "other-run-b", repositoryID: repo.id,
            pullRequestOwnerLogin: "brian",
            projectLinks: [.init(id: "maple-roof", title: "Maple Roof")],
            observedAt: base.addingTimeInterval(210),
            updatedAt: base.addingTimeInterval(210))
        try await repository.appendEvent(ProvenanceEvent(eventType: .workspaceDisplayObserved,
            timestamp: display.observedAt, repositoryID: repo.id,
            source: .observed, confidence: .high,
            payload: ProvenanceEventPayload(workspaceDisplay: display)))
        let first = try await repository.workspaceHistory(.init(limit: 1))
        #expect(first.workspaces.map(\.id) == ["other-run-b"])
        #expect(first.workspaces.first?.lastKnownDirectory == "/work/other-run-b")
        #expect(first.workspaces.first?.lastKnownRepositoryID == repo.id)
        let second = try await repository.workspaceHistory(.init(limit: 1, cursor: first.nextCursor))
        #expect(second.workspaces.map(\.id) == ["other-run-a"])
        #expect(second.workspaces.first?.lastActivityAt == base.addingTimeInterval(100))
        #expect(second.nextCursor == nil)
        let facets = try await repository.workspaceHistoryFacets().facets
        #expect(facets.map(\.workspaceID) == ["other-run-b", "other-run-a"])
        #expect(facets.first?.repositoryID == repo.id)
        #expect(facets.first?.projectLinks.map(\.id) == ["maple-roof"])
        #expect(facets.first?.pullRequestOwnerLogin == "brian")
        try await repository.clearArchivedWorkspaces(at: base.addingTimeInterval(150))
        #expect(try await repository.workspaceHistory(.init()).workspaces.map(\.id) == ["other-run-b"])
        #expect(try await repository.workspaceHistoryFacets().facets.map(\.workspaceID) == ["other-run-b"])
    }

    @Test
    func completedCommandCountsAsWorkspaceActivity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-activity-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(id: "session-a", agentKind: "codex",
            workspaceID: "stable-a", status: "completed",
            startedAt: base, updatedAt: base.addingTimeInterval(900))
        try await repository.appendEvent(ProvenanceEvent(eventType: .sessionObserved,
            timestamp: session.updatedAt, sessionID: session.id, source: .observed,
            confidence: .high, payload: ProvenanceEventPayload(session: session)))
        let command = ProvenanceCodingAgentCommandRecord(id: "command-a", sessionID: session.id,
            provider: "codex", command: "swift test", status: "succeeded",
            completedAt: base.addingTimeInterval(300), source: .observed, confidence: .high)
        try await repository.appendEvent(ProvenanceEvent(eventType: .codingAgentCommandCompleted,
            timestamp: command.completedAt, sessionID: session.id, source: .observed,
            confidence: .high, payload: ProvenanceEventPayload(codingAgentCommand: command)))
        let page = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(page.sessions.first?.lastActivityAt == command.completedAt)
        let message = ProvenanceCodingAgentAssistantMessageRecord(id: "message-a",
            sessionID: session.id, provider: "codex", text: "The tests pass.",
            completedAt: base.addingTimeInterval(500), source: .observed, confidence: .high)
        try await repository.appendEvent(ProvenanceEvent(eventType: .codingAgentAssistantMessageCompleted,
            timestamp: message.completedAt, sessionID: session.id, source: .observed,
            confidence: .high, payload: ProvenanceEventPayload(codingAgentAssistantMessage: message)))
        let afterMessage = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(afterMessage.sessions.first?.lastActivityAt == message.completedAt)
        _ = try await repository.rebuildProjectionsFromEventLedger()
        let rebuilt = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(rebuilt.sessions.first?.lastActivityAt == message.completedAt)
    }

    @Test
    func planAndFileChangeEvidenceAdvanceWorkspaceActivity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-plan-file-activity-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(id: "session-a", agentKind: "codex",
            workspaceID: "stable-a", status: "running", startedAt: base,
            updatedAt: base.addingTimeInterval(900))
        try await repository.appendEvent(ProvenanceEvent(eventType: .sessionObserved,
            timestamp: session.updatedAt, sessionID: session.id, source: .observed,
            confidence: .high, payload: ProvenanceEventPayload(session: session)))
        let plan = ProvenanceCodingAgentPlanUpdateRecord(id: "plan-a", sessionID: session.id,
            provider: "codex", steps: [], observedAt: base.addingTimeInterval(300),
            source: .observed, confidence: .high)
        try await repository.appendEvent(ProvenanceEvent(eventType: .codingAgentPlanUpdated,
            timestamp: plan.observedAt, sessionID: session.id, source: .observed,
            confidence: .high, payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)))
        let afterPlan = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(afterPlan.sessions.first?.lastActivityAt == plan.observedAt)
        let fileChange = ProvenanceCodingAgentFileChangeAttributionRecord(id: "file-a",
            sessionID: session.id, provider: "codex", paths: ["Sources/RoofReport.swift"],
            observedAt: base.addingTimeInterval(500), source: .observed, confidence: .high)
        try await repository.appendEvent(ProvenanceEvent(eventType: .codingAgentFileChangeAttributed,
            timestamp: fileChange.observedAt, sessionID: session.id, source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(codingAgentFileChangeAttribution: fileChange)))
        let afterFile = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(afterFile.sessions.first?.lastActivityAt == fileChange.observedAt)
        _ = try await repository.rebuildProjectionsFromEventLedger()
        let rebuilt = try await repository.workspaceSessions(.init(workspaceID: "stable-a"))
        #expect(rebuilt.sessions.first?.lastActivityAt == fileChange.observedAt)
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
            colorHex: "#3B6FD6", coverageCode: "codex_only", lastRecordedStatusCode: "running"
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
        #expect(try await reopenedClient.schemaVersion() == 28)
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
            displayAtClose: nil, colorHex: nil, coverageCode: nil, lastRecordedStatusCode: "running"
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
        #expect(try await repository.archivedWorkspaces(.init()).records.first?.lastRecordedStatusCode == nil)
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

    @Test
    func recoveryFallbackCannotEraseEnrichedRecordForSameClose() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-archive-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(
            url: directory.appendingPathComponent("provenance.sqlite")
        )
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let enriched = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Maple Street Roof Inspection",
            createdAt: closedAt.addingTimeInterval(-3600), closedAt: closedAt,
            lastActivityAt: closedAt.addingTimeInterval(-60), displayAtClose: nil,
            colorHex: "#3B6FD6", coverageCode: nil,
            lastRecordedStatusCode: "running"
        )
        let fallback = ProvenanceArchivedWorkspaceRecord(
            id: "stable-a", title: "Maple Street Roof Inspection",
            createdAt: nil, closedAt: closedAt, lastActivityAt: nil,
            displayAtClose: nil, colorHex: "#3B6FD6",
            coverageCode: "close_snapshot_recovery"
        )

        try await repository.recordArchivedWorkspace(fallback)
        try await repository.recordArchivedWorkspace(enriched)
        #expect(try await repository.archivedWorkspaces(.init()).records == [enriched])
        try await repository.recordArchivedWorkspace(fallback)

        #expect(try await repository.archivedWorkspaces(.init()).records == [enriched])
    }
}
