import Foundation
import ProvenanceEngineContracts
import Testing
import BmuxWorkspaces

@Suite @MainActor
struct WorkspaceExplorerSessionPageStoreTests {
    @Test
    func continuationKeepsUniqueSessionsAndTotal() async {
        let id = UUID()
        let store = WorkspaceExplorerSessionPageStore(
            loadFirst: { workspaceID in
                Self.page(workspaceID, ids: ["first"], cursor: "next", total: 3)
            },
            loadNext: { workspaceID, cursor in
                #expect(cursor == "next")
                return Self.page(workspaceID, ids: ["first", "second"], cursor: nil, total: 3)
            })

        store.activate(id.uuidString)
        await store.loadFirstPage(for: id.uuidString)
        await store.loadNextPage(for: id.uuidString)

        #expect(store.pagesByWorkspaceID[id.uuidString]?.sessions.map(\.id) == ["first", "second"])
        #expect(store.pagesByWorkspaceID[id.uuidString]?.totalCount == 3)
    }

    private static func page(_ id: UUID, ids: [String], cursor: String?, total: Int)
        -> ProvenanceWorkspaceSessionPageResponse {
        ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
            sessions: ids.map { sessionID in
                ProvenanceWorkspaceSessionSummary(session: ProvenanceSessionRecord(
                    id: sessionID, agentKind: "codex", status: "completed", updatedAt: .now),
                    lastActivityAt: .now)
            }, nextCursor: cursor, totalCount: total)
    }
}
