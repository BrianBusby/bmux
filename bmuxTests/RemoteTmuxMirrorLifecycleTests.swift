import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Regression tests for remote-tmux mirror detach behavior. They use cached,
/// unstarted control connections so no ssh/tmux ever attaches anywhere. The
/// last-mirror teardown does fire-and-forget the production `ssh -O exit` at
/// bmux's own (nonexistent here) ControlPath socket — a local-only no-op that
/// exits immediately; a test seam to suppress it is exactly the production
/// test-scaffolding bmux policy forbids.
@MainActor
@Suite(.serialized)
struct RemoteTmuxMirrorLifecycleTests {
    private func mirror(
        controller: RemoteTmuxController,
        manager: TabManager,
        host: RemoteTmuxHost,
        sessionName: String
    ) throws -> RemoteTmuxControlConnection {
        let connection = RemoteTmuxControlConnection(host: host, sessionName: sessionName)
        controller.cacheConnection(connection)
        let mirrored = try controller.mirrorSession(host: host, sessionName: sessionName, into: manager)
        #expect(mirrored)
        return connection
    }

    @Test func detachRemovesMirrorWorkspaceAndStopsConnection() throws {
        let controller = RemoteTmuxController()
        let manager = TabManager()
        let host = RemoteTmuxHost(destination: "user@host")
        let connection = try mirror(
            controller: controller,
            manager: manager,
            host: host,
            sessionName: "dev"
        )

        let mirrorWorkspace = try #require(manager.tabs.first { $0.title == "dev" && $0.isRemoteTmuxMirror })
        #expect(manager.tabs.contains { $0.id == mirrorWorkspace.id })
        #expect(manager.setWorkspacePinnedForAction(tabId: mirrorWorkspace.id, pinned: true))

        controller.detach(host: host, sessionName: "dev")

        #expect(!manager.tabs.contains { $0.id == mirrorWorkspace.id })
        #expect(manager.tabs.count == 1)
        #expect(manager.tabs.allSatisfy { !$0.isRemoteTmuxMirror })
        #expect(connection.exited)
    }

    @Test func detachOneOfTwoMirrorsRemovesOnlyThatWorkspace() throws {
        let controller = RemoteTmuxController()
        let manager = TabManager()
        let host = RemoteTmuxHost(destination: "user@host")
        let alpha = try mirror(
            controller: controller,
            manager: manager,
            host: host,
            sessionName: "alpha"
        )
        let beta = try mirror(
            controller: controller,
            manager: manager,
            host: host,
            sessionName: "beta"
        )

        let alphaWorkspace = try #require(manager.tabs.first { $0.title == "alpha" && $0.isRemoteTmuxMirror })
        let betaWorkspace = try #require(manager.tabs.first { $0.title == "beta" && $0.isRemoteTmuxMirror })

        controller.detach(host: host, sessionName: "alpha")

        #expect(!manager.tabs.contains { $0.id == alphaWorkspace.id })
        #expect(manager.tabs.contains { $0.id == betaWorkspace.id })
        #expect(alpha.exited)
        #expect(!beta.exited)
    }

    @Test func remoteWindowCloseRemovesMirrorSurfaceWithoutClosedHistory() throws {
        ClosedItemHistoryStore.shared.removeAll()
        defer { ClosedItemHistoryStore.shared.removeAll() }

        let controller = RemoteTmuxController()
        let manager = TabManager()
        let host = RemoteTmuxHost(destination: "user@host")
        let connection = try mirror(
            controller: controller,
            manager: manager,
            host: host,
            sessionName: "dev"
        )
        let mirrorWorkspace = try #require(manager.tabs.first { $0.title == "dev" && $0.isRemoteTmuxMirror })

        connection.handleMessageForTesting(.layoutChange(windowId: 1, layout: "f92f,80x24,0,0,4"))
        let firstWindowPanels = Set(mirrorWorkspace.panels.keys)
        #expect(firstWindowPanels.count == 1)

        connection.handleMessageForTesting(.layoutChange(windowId: 2, layout: "abcd,80x24,0,0,5"))
        let twoWindowPanels = Set(mirrorWorkspace.panels.keys)
        #expect(twoWindowPanels.count == 2)
        let secondWindowPanels = twoWindowPanels.subtracting(firstWindowPanels)
        #expect(secondWindowPanels.count == 1)

        connection.handleMessageForTesting(.windowClose(windowId: 1))

        #expect(Set(mirrorWorkspace.panels.keys) == secondWindowPanels)
        #expect(ClosedItemHistoryStore.shared.canReopen == false)
    }
}
