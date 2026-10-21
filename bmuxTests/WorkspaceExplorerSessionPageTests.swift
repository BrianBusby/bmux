import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerSessionPageTests {
    @Test
    func lateFirstPageCannotReplaceNewerResult() async {
        let id = UUID()
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        var calls = 0
        let model = model(loadFirst: { workspaceID in
            calls += 1
            if calls == 1 {
                started.continuation.yield()
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
                return page(workspaceID, ids: ["old"], cursor: nil, total: 1)
            }
            return page(workspaceID, ids: ["new"], cursor: nil, total: 1)
        })
        model.showHistory(id.uuidString)
        let oldLoad = Task { await model.loadHistorySessions(for: id.uuidString) }
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()
        await model.loadHistorySessions(for: id.uuidString)
        release.continuation.yield()
        await oldLoad.value
        #expect(model.sessionsByWorkspaceID[id.uuidString]?.sessions.map(\.id) == ["new"])
    }

    @Test
    func nextPageRetainsUniqueTotal() async {
        let id = UUID()
        let model = model(loadFirst: { workspaceID in
            page(workspaceID, ids: ["one"], cursor: "next", total: 3)
        }, loadNext: { workspaceID, cursor in
            #expect(cursor == "next")
            return page(workspaceID, ids: ["two"], cursor: nil, total: 3)
        })
        model.showHistory(id.uuidString)
        await model.loadHistorySessions(for: id.uuidString)
        await model.loadMoreHistorySessions(for: id.uuidString)
        #expect(model.sessionsByWorkspaceID[id.uuidString]?.sessions.map(\.id) == ["one", "two"])
        #expect(model.sessionsByWorkspaceID[id.uuidString]?.totalCount == 3)
    }

    private func model(
        loadFirst: @escaping WorkspaceExplorerCoordinator.SessionLoader,
        loadNext: @escaping WorkspaceExplorerCoordinator.MoreSessionsLoader = { _, _ in
            throw CancellationError()
        }
    ) -> WorkspaceExplorerCoordinator {
        WorkspaceExplorerCoordinator(
            loadHistory: { WorkspaceExplorerHistoryLoadResult(items: [],
                archiveAvailability: .available, partialLiveActivity: false) },
            reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: loadFirst, loadMoreSessions: loadNext, clearArchive: { }
        )
    }

    private func page(_ id: UUID, ids: [String], cursor: String?, total: Int)
        -> ProvenanceWorkspaceSessionPageResponse {
        ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
            sessions: ids.map { sessionID in
                ProvenanceWorkspaceSessionSummary(session: ProvenanceSessionRecord(
                    id: sessionID, agentKind: "codex", status: "completed", updatedAt: .now),
                    lastActivityAt: .now)
            }, nextCursor: cursor, totalCount: total)
    }
}
