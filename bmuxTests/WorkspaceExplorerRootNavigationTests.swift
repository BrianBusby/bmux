import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerRootNavigationTests {
    @Test
    func rootLoadsSessionsFromAnotherBmuxRunWithoutAnArchive() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-explorer-cross-run-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"))
        let workspaceID = UUID()
        let activity = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(id: "codex-other-run", agentKind: "codex",
            workspaceID: workspaceID.uuidString, cwd: "/work/maple-roof", status: "completed",
            startedAt: activity, updatedAt: activity)
        _ = try await client.appendEvent(.init(event: .init(eventType: .sessionObserved,
            timestamp: activity, sessionID: session.id, source: .observed,
            confidence: .high, payload: .init(session: session))))
        let service = WorkspaceExplorerHistoryService(
            archiveService: WorkProvenanceWorkspaceArchiveService(client: client),
            tabManagers: { [] }, activeWorkspaceID: { nil }, restoreRecords: { [:] },
            reopenEligibility: { _, _, _ in .unavailable(.noRestoreSnapshot) })

        let result = try await service.load()
        #expect(result.items.count == 1)
        #expect(result.items[0].id == workspaceID.uuidString)
        #expect(result.items[0].title == "maple-roof")
        #expect(result.items[0].isSessionHistoryOnly)
        #expect(result.archiveAvailability == .available)
    }

    @Test
    func rootReadsTwentyFiveHistoricalWorkspacesPerCursorPage() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-explorer-pages-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<27 {
            let session = ProvenanceSessionRecord(id: "other-run-\(index)", agentKind: "codex",
                workspaceID: UUID().uuidString, status: "completed",
                startedAt: base.addingTimeInterval(Double(index)),
                updatedAt: base.addingTimeInterval(Double(index)))
            _ = try await client.appendEvent(.init(event: .init(eventType: .sessionObserved,
                timestamp: session.updatedAt, sessionID: session.id, source: .observed,
                confidence: .high, payload: .init(session: session))))
        }
        let service = WorkspaceExplorerHistoryService(
            archiveService: WorkProvenanceWorkspaceArchiveService(client: client),
            tabManagers: { [] }, activeWorkspaceID: { nil }, restoreRecords: { [:] },
            reopenEligibility: { _, _, _ in .unavailable(.noRestoreSnapshot) })

        let first = try await service.load()
        #expect(first.items.count == 25)
        let cursor = try #require(first.nextHistoryCursor)
        let second = try await service.moreSessionWorkspaces(cursor: cursor)
        #expect(second.items.count == 2)
        #expect(second.nextHistoryCursor == nil)
        #expect(Set(first.items.map(\.id)).isDisjoint(with: Set(second.items.map(\.id))))
    }

    @Test
    func repositoryFilterContinuesThroughPagesUntilTwentyFiveMatches() async {
        let first = Self.historyItems(count: 25, repository: "other", project: "cedar-roof")
        let skipped = Self.historyItems(count: 25, repository: "other")
        let matching = Self.historyItems(count: 25, repository: "maple")
        let laterFacet = ProvenanceWorkspaceHistoryFacet(workspaceID: matching[0].id,
            lastActivityAt: matching[0].lastActivityAt, repositoryID: "maple",
            projectLinks: [.init(id: "maple-roof", title: "Maple Roof")],
            pullRequestOwnerLogin: "brian")
        let unassignedFacet = ProvenanceWorkspaceHistoryFacet(workspaceID: matching[1].id,
            lastActivityAt: matching[1].lastActivityAt, repositoryID: "maple",
            projectLinks: [], pullRequestOwnerLogin: nil)
        var cursors: [String] = []
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: first,
                archiveAvailability: .available, partialLiveActivity: false,
                nextHistoryCursor: "after-first", filterFacets: [laterFacet, unassignedFacet]) },
            loadMoreHistory: { cursor in
                cursors.append(cursor)
                return WorkspaceExplorerHistoryLoadResult(
                    items: cursor == "after-first" ? skipped : matching,
                    archiveAvailability: .available, partialLiveActivity: false,
                    nextHistoryCursor: cursor == "after-first" ? "after-second" : nil)
            },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { })
        await model.load()
        let options = model.catalog?.filterOptions(
            dimensions: [.repository, .project, .pullRequestOwner], target: .all,
            scope: model.scope,
            inScopeWorkspaceIDs: model.result()?.inScopeWorkspaceIDs ?? [], now: .now,
            calendar: .current)
        #expect(options?[.repository]?.contains(.value("maple")) == true)
        #expect(options?[.project]?.contains(.project("maple-roof")) == true)
        #expect(options?[.project]?.contains(.unassigned) == true)
        #expect(options?[.pullRequestOwner]?.contains(.value("brian")) == true)
        model.rootArrangement.setFilter(.repository, value: .value("maple"))

        await model.loadMoreHistoryPage()

        #expect(cursors == ["after-first", "after-second"])
        #expect(model.result()?.visibleWorkspaceIDs.count == 25)
        #expect(model.hasMoreHistory == false)
    }

    private static func historyItems(count: Int, repository: String,
                                     project: String? = nil) -> [WorkspaceExplorerHistoryItem] {
        let summaries = (0..<count).map { index in
            let id = UUID().uuidString
            let activity = Date(timeIntervalSince1970: 1_800_000_000 - Double(index))
            let display = project.map { project in
                ProvenanceWorkspaceDisplayRecord(id: "display-\(id)", workspaceID: id,
                    projectLinks: [.init(id: project, title: "Cedar Roof")],
                    observedAt: activity, updatedAt: activity)
            }
            return ProvenanceWorkspaceHistorySummary(id: id, firstSessionAt: nil,
                lastActivityAt: activity,
                sessionCount: 1, lastKnownDirectory: "/work/maple-roof",
                lastKnownRepositoryID: repository, display: display)
        }
        return WorkspaceExplorerHistoryAdapter().join(live: [], archived: [],
            sessionWorkspaces: summaries, eligibilityByID: [:])
    }

    @Test
    func laterSessionActivityMakesAnArchivedRowUnverified() async throws {
        let id = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let archive = ProvenanceArchivedWorkspaceRecord(id: id.uuidString,
            title: "Maple Street Roof Inspection", createdAt: nil, closedAt: closedAt,
            lastActivityAt: closedAt, displayAtClose: nil, colorHex: nil, coverageCode: nil)
        let first = try #require(WorkspaceExplorerHistoryAdapter().join(live: [],
            archived: [archive], eligibilityByID: [id: .eligible(recordID: id)]).first)
        let later = ProvenanceWorkspaceHistorySummary(id: id.uuidString, firstSessionAt: closedAt,
            lastActivityAt: closedAt.addingTimeInterval(60), sessionCount: 1,
            lastKnownRepositoryID: "maple")
        let pageItem = try #require(WorkspaceExplorerHistoryAdapter().join(live: [], archived: [],
            sessionWorkspaces: [later], eligibilityByID: [:]).first)
        let combined = WorkspaceExplorerHistoryLoadResult(items: [first],
            archiveAvailability: .available, partialLiveActivity: false,
            nextHistoryCursor: "later").appendingHistoryPage(
                WorkspaceExplorerHistoryLoadResult(items: [pageItem],
                    archiveAvailability: .available, partialLiveActivity: false))
        let item = try #require(combined.items.first)
        #expect(combined.items.count == 1)
        #expect(item.hasUnverifiedPresence)
        #expect(item.lastActivityAt == later.lastActivityAt)
        #expect(item.repositoryID == "maple")
        var attemptedReopen = false
        let model = WorkspaceExplorerCoordinator(loadHistory: { combined },
            reopenHistory: { _ in attemptedReopen = true; return true },
            activateWorkspace: { _ in },
            loadSessions: { stableID in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: stableID.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { })
        #expect(await model.reopen(item) == false)
        #expect(!attemptedReopen)
    }

    @Test
    func rootShowsWorkspacesAndSupportsGroupingAndFiltering() async {
        let first = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .needsInput)
        let second = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Cedar Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: .now, liveStatus: .idle)
        let items = WorkspaceExplorerHistoryAdapter().join(live: [first, second], archived: [],
            eligibilityByID: [:])
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: items,
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { })
        await model.load()

        #expect(model.collectionTarget == nil)
        #expect(Set(model.result()?.visibleWorkspaceIDs ?? []) ==
            Set([first.stableID.uuidString, second.stableID.uuidString]))
        #expect(model.result()?.groups.first?.projectIDs.isEmpty == true)

        model.setGroupBy([.bmuxStatus])
        #expect(model.result()?.groups.count == 2)
        model.setFilter(.bmuxStatus, value: .bmuxStatus(.needsInput))
        #expect(model.result()?.visibleWorkspaceIDs == [first.stableID.uuidString])
    }

    @Test
    func openingExplorerResetsToAllWorkspacesWithoutFiltersOrGrouping() {
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { })
        model.showCollection(.all)
        model.setGroupBy([.repository])
        model.setFilter(.bmuxStatus, value: .bmuxStatus(.needsInput))
        model.scope = WorkspaceExplorerScope(state: .open, period: .today)
        model.showCollection(.project("maple-roof"))
        model.showHistory("history")

        model.openAllWorkspacesUnfiltered()

        #expect(model.collectionTarget == nil)
        #expect(model.historyID == nil)
        #expect(model.scope == WorkspaceExplorerScope(state: .all, period: .anyTime))
        #expect(model.activeArrangement.groupBy.isEmpty)
        #expect(model.activeArrangement.filters.isEmpty)
        #expect(!model.activeArrangement.canUndo)

        model.setGroupBy([.project])
        model.setFilter(.repository, value: .value("bmux"))
        model.openAllWorkspacesUnfiltered()
        #expect(model.activeArrangement.groupBy.isEmpty)
        #expect(model.activeArrangement.filters.isEmpty)
    }
    @Test
    func openingLiveWorkspaceKeepsProjectRouteAndArrangement() async {
        let workspace = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil, liveStatus: .idle)
        let item = WorkspaceExplorerHistoryAdapter().join(live: [workspace], archived: [],
            eligibilityByID: [:])[0]
        var opened: (WorkspaceExplorerHistoryItem, WorkspaceExplorerCollectionTarget?, String)?
        var activated: UUID?
        let model = WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [item],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false },
            activateWorkspace: { activated = $0 },
            onOpenLive: { opened = ($0, $1, $2) },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) },
            clearArchive: { }
        )
        await model.load()
        model.showCollection(.unassigned)
        model.setGroupBy([.repository])
        model.open(item)
        #expect(opened?.0.id == workspace.stableID.uuidString)
        #expect(opened?.1 == .unassigned)
        #expect(opened?.2 == String(localized: "explorer.unassigned", defaultValue: "Unassigned workspaces"))
        #expect(activated == workspace.runtimeID)
        #expect(model.collectionTarget == .unassigned)
        #expect(model.activeArrangement.groupBy == [.repository])
    }
}
