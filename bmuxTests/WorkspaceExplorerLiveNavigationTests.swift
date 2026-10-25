import AppKit
import Foundation
import Observation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerLiveNavigationTests {
    @Test
    func originInvalidatesTitlebarBeforeExplorerWindowRegisters() {
        let navigation = WorkspaceExplorerLiveNavigation()
        let changed = DispatchSemaphore(value: 0)
        withObservationTracking {
            _ = navigation.origin(for: nil)
        } onChange: {
            changed.signal()
        }
        navigation.opened(item: item(), target: .unassigned,
            from: "Unassigned workspaces", loadSessions: { id in
                ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil, totalCount: 0)
            })
        #expect(changed.wait(timeout: .now()) == .success)
    }

    @Test
    func liveHeaderOpensRetainedHistoryAndNavigatesTheSavedCollection() async {
        let workspace = item()
        let model = coordinator(item: workspace)
        await model.load()
        model.showCollection(.unassigned)
        let navigation = WorkspaceExplorerLiveNavigation(raise: { _ in })
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        navigation.register(window: window, coordinator: model)
        navigation.opened(item: workspace, target: .unassigned,
            from: "Unassigned workspaces", loadSessions: { id in
                ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil, totalCount: 2)
            })
        #expect(await waitForCount(2, navigation: navigation))
        #expect(navigation.origin(for: workspace.liveWorkspaceID)?.stableID.uuidString == workspace.id)

        model.showAllWorkspaces()
        navigation.openHistory()
        #expect(model.historyID == workspace.id)
        #expect(model.collectionTarget == .unassigned)
        navigation.returnToAllWorkspaces()
        #expect(model.historyID == nil)
        #expect(model.collectionTarget == nil)
        navigation.returnToCollection()
        #expect(model.collectionTarget == .unassigned)
        navigation.unregister()
        #expect(navigation.origin(for: workspace.liveWorkspaceID) == nil)
    }

    @Test
    func zeroRetainedSessionsDoNotOpenHistory() async {
        let workspace = item()
        let model = coordinator(item: workspace)
        await model.load()
        let navigation = WorkspaceExplorerLiveNavigation(raise: { _ in })
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        navigation.register(window: window, coordinator: model)
        navigation.opened(item: workspace, target: nil,
            from: "All workspaces", loadSessions: { id in
                ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil, totalCount: 0)
            })
        #expect(await waitForCount(0, navigation: navigation))
        navigation.openHistory()
        #expect(model.historyID == nil)
        navigation.unregister()
    }

    @Test
    func olderSessionCountCannotReplaceNewWorkspaceOrigin() async {
        let first = item()
        let second = item()
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let navigation = WorkspaceExplorerLiveNavigation()
        navigation.opened(item: first, target: .unassigned,
            from: "Unassigned workspaces", loadSessions: { id in
                started.continuation.yield()
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
                return ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil, totalCount: 4)
            })
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()
        navigation.opened(item: second, target: .all,
            from: "All workspaces", loadSessions: { id in
                ProvenanceWorkspaceSessionPageResponse(workspaceID: id.uuidString,
                    sessions: [], nextCursor: nil, totalCount: 1)
            })
        #expect(await waitForCount(1, navigation: navigation))
        release.continuation.yield()
        await Task.yield()
        #expect(navigation.origin?.stableID.uuidString == second.id)
        #expect(navigation.retainedSessionCount == 1)
        navigation.unregister()
    }

    private func item() -> WorkspaceExplorerHistoryItem {
        let workspace = WorkspaceExplorerLiveWorkspace(stableID: UUID(), runtimeID: UUID(),
            title: "Maple Street Roof Inspection", createdAt: .now,
            colorHex: nil, display: nil, lastActivityAt: nil)
        return WorkspaceExplorerHistoryAdapter().join(live: [workspace], archived: [],
            eligibilityByID: [:])[0]
    }

    private func coordinator(item: WorkspaceExplorerHistoryItem) -> WorkspaceExplorerCoordinator {
        WorkspaceExplorerCoordinator(loadHistory: {
            WorkspaceExplorerHistoryLoadResult(items: [item], archiveAvailability: .available,
                partialLiveActivity: false)
        }, reopenHistory: { _ in false }, activateWorkspace: { _ in },
            loadSessions: { id in ProvenanceWorkspaceSessionPageResponse(
                workspaceID: id.uuidString, sessions: [], nextCursor: nil) }, clearArchive: { })
    }

    private func waitForCount(_ count: Int, navigation: WorkspaceExplorerLiveNavigation) async -> Bool {
        for _ in 0..<1000 {
            if navigation.retainedSessionCount == count { return true }
            await Task.yield()
        }
        return false
    }
}
