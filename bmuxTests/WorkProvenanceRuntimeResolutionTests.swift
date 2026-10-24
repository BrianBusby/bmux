import Combine
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct WorkProvenanceRuntimeResolutionTests {
    @MainActor
    @Test
    func workspaceResolverSearchesAllCandidateManagersByRuntimeOrStableID() throws {
        let firstManager = TabManager(), secondManager = TabManager()
        let firstWorkspace = Workspace(title: "First Workspace"), targetWorkspace = Workspace(title: "Prompt Linked Workspace")
        firstManager.tabs = [firstWorkspace]; secondManager.tabs = [targetWorkspace]
        var immediateObservationCount = 0
        let cancellable = targetWorkspace.sidebarImmediateObservationChangeSubject.sink { immediateObservationCount += 1 }
        defer { cancellable.cancel() }
        let managers = [firstManager, secondManager]
        let match = try #require(WorkProvenanceRuntime.workspaceMatch(matching: targetWorkspace.stableId, in: managers))

        #expect(WorkProvenanceRuntime.workspace(matching: targetWorkspace.id, in: managers) === targetWorkspace)
        #expect(WorkProvenanceRuntime.workspace(matching: targetWorkspace.stableId, in: managers) === targetWorkspace)
        #expect(match.tabManager === secondManager)
        #expect(match.workspace === targetWorkspace)
        #expect(WorkProvenanceRuntime.stableWorkspaceIDs(in: managers + [secondManager]) == [firstWorkspace.stableId, targetWorkspace.stableId])
        #expect(WorkProvenanceRuntime.notifyWorkspaceDisplayCurrentStateDidChange(
            stableWorkspaceID: targetWorkspace.stableId,
            in: managers
        ))
        #expect(immediateObservationCount == 1)
    }

    @MainActor
    @Test
    func explorerRefreshesWhenAWorkspaceDisplayChanges() {
        let manager = TabManager()
        let workspace = Workspace(title: "Review roof inspection")
        manager.tabs = [workspace]
        let monitor = WorkspaceExplorerWorkspaceChangeMonitor(tabManagers: { [manager] })
        var refreshCount = 0
        monitor.start { refreshCount += 1 }
        defer { monitor.stop() }

        #expect(WorkProvenanceRuntime.notifyWorkspaceDisplayCurrentStateDidChange(
            stableWorkspaceID: workspace.stableId, in: [manager]))
        #expect(refreshCount == 1)
    }
}
