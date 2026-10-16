import BmuxGit
import BmuxSidebar
import BmuxSidebarGit
import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct WorkspaceGitSnapshotCoalescingTests {
    private enum Failure: Error { case snapshotApplicationTimedOut }

    @Test func sameDirectoryInitialGitMetadataProbesShareOneSnapshotRead() async throws {
        let defaults = UserDefaults.standard
        let key = SidebarWorkspaceDetailDefaults.watchGitStatusKey
        let previous = defaults.object(forKey: key)
        defaults.set(false, forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "bmux-git-coalesced-probes-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error) }
        }
        let reader = BlockingWorkspaceGitMetadataReader(metadata: GitWorkspaceMetadata(
            isRepository: true, branch: "main", isDirty: false, indexSignature: "index",
            indexContentSignature: "content", headSignature: "head"
        ))
        let manager = makeSidebarGitObservedTabManager(
            workspaceGitMetadataReader: reader, mobileHostDeferral: .disabledForSidebarGitTests
        )
        defer {
            for workspace in manager.tabs {
                workspace.teardownRemoteConnection()
                workspace.teardownAllPanels()
            }
        }
        let result: Result<Void, Error>
        do {
            try await verifySnapshot(manager: manager, reader: reader, directory: directory, defaults: defaults)
            result = .success(())
        } catch {
            result = .failure(error)
        }
        // Existing service cancellation clears its host; join only owned reader
        // and observation work, not a fabricated private service-task registry.
        manager.sidebarGitMetadataService.stopSidebarGitMetadataObservation()
        manager.pullRequestProbing.stopWorkspacePullRequestObservation()
        await reader.releaseAllAndDrain()
        #expect(await reader.activeCallCount == 0)
        #expect(await reader.observationCount == 0)
        try result.get()
    }

    private func verifySnapshot(
        manager: TabManager,
        reader: BlockingWorkspaceGitMetadataReader,
        directory: URL,
        defaults: UserDefaults
    ) async throws {
        let workspace = try #require(manager.selectedWorkspace)
        let mainPanelId = try #require(workspace.focusedPanelId)
        let paneId = try #require(workspace.bonsplitController.focusedPaneId)
        let splitPanel = try #require(workspace.newTerminalSplit(from: mainPanelId, orientation: .horizontal, focus: false))
        let tabPanel = try #require(workspace.newTerminalSurface(inPane: paneId))
        let panelIds = [mainPanelId, splitPanel.id, tabPanel.id]
        for panelId in panelIds {
            manager.updateSurfaceDirectory(tabId: workspace.id, surfaceId: panelId, directory: directory.path)
        }

        let firstRead = await reader.observeCallCounts()
        let firstDeadline = ContinuousClock().now.advanced(by: .seconds(1))
        defaults.set(true, forKey: SidebarWorkspaceDetailDefaults.watchGitStatusKey)
        manager.sidebarGitMetadataWatchSettingsDidChangeForTesting()
        let didStart = try await reader.waitForCallCount(1, observation: firstRead, until: firstDeadline)
        #expect(didStart, "Expected first git snapshot read within one second")

        let secondRead = await reader.observeCallCounts()
        let didStartSecond = try await reader.waitForCallCount(
            2, observation: secondRead, until: ContinuousClock().now.advanced(by: .milliseconds(200))
        )
        #expect(!didStartSecond, "Same-directory requests must not start an uncoalesced second read")
        #expect(await reader.observedCallCount == 1)
        #expect(await reader.observedMaxActiveCallCount == 1)

        try await releaseAndObserveApplication(reader: reader, workspace: workspace, panelIds: panelIds, within: .seconds(3))
        #expect(panelIds.allSatisfy { workspace.panelGitBranches[$0]?.branch == "main" },
                "One same-directory snapshot should update every queued panel.")
        #expect(await reader.observedCallCount == 1)
    }

    private func releaseAndObserveApplication(
        reader: BlockingWorkspaceGitMetadataReader,
        workspace: Workspace,
        panelIds: [UUID],
        within duration: Duration
    ) async throws {
        let (events, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let workspaceId = workspace.id
        let observer = NotificationCenter.default.addObserver(
            forName: .workspaceDisplayMetadataDidChange, object: nil, queue: nil
        ) { notification in
            guard notification.userInfo?["workspaceId"] as? UUID == workspaceId else { return }
            // Workspace publishes synchronously on MainActor after its mutation.
            MainActor.assumeIsolated {
                if panelIds.allSatisfy({ workspace.panelGitBranches[$0]?.branch == "main" }) {
                    continuation.yield(())
                    continuation.finish()
                }
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            continuation.finish()
        }
        let deadline = ContinuousClock().now.advanced(by: duration)
        await reader.releaseAll()
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in events { return }
                try Task.checkCancellation()
            }
            group.addTask {
                // Bound missing publication by the original three-second failure limit.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.snapshotApplicationTimedOut
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }
}
