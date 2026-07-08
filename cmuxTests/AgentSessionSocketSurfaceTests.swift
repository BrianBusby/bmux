import Foundation
import Combine
import XCTest
import Testing
import CmuxAgentChat
import CmuxSidebar

#if canImport(cmux_DEV)
    @testable import cmux_DEV
#elseif canImport(cmux)
    @testable import cmux
#endif

@Suite(.serialized)
@MainActor
struct AgentSessionSocketSurfaceTests {
    @Test
    func testPanelTypeParserAcceptsAgentSessionSpellings() {
        let controller = TerminalController.shared

        for rawValue in [
            "agentSession", "agent-session", "agent_session", "agent session", "agentsession",
        ] {
            expectEqual(
                controller.v2PanelType(["type": rawValue], "type"),
                .agentSession,
                "Expected \(rawValue) to parse as an agent session surface"
            )
        }
    }

    @Test
    func testWorkspaceCreatesAgentSessionSurfaceWithProviderAndRenderer() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let paneId = try #require(workspace.bonsplitController.focusedPaneId)

        let panel = try #require(
            workspace.newAgentSessionSurface(
                inPane: paneId,
                providerID: .opencode,
                rendererKind: .solid,
                workingDirectory: "/tmp",
                focus: true
            )
        )

        expectEqual(panel.panelType, .agentSession)
        expectEqual(panel.initialProviderID, .opencode)
        expectEqual(panel.rendererKind, .solid)
        expectEqual(panel.workingDirectory, "/tmp")
        expectEqual(workspace.panelDirectories[panel.id], "/tmp")
        expectEqual(workspace.focusedPanelId, panel.id)
    }

    @Test
    func testWorkspaceSessionSnapshotPersistsAgentSessionWorkingDirectory() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let paneId = try #require(workspace.bonsplitController.focusedPaneId)

        let panel = try #require(
            workspace.newAgentSessionSurface(
                inPane: paneId,
                providerID: .codex,
                rendererKind: .react,
                workingDirectory: "/tmp/cmux-agent-session-cwd",
                focus: true
            )
        )

        let snapshot = workspace.sessionSnapshot(includeScrollback: false)
        let panelSnapshot = try #require(snapshot.panels.first { $0.id == panel.id })
        expectEqual(panelSnapshot.directory, "/tmp/cmux-agent-session-cwd")
        expectEqual(panelSnapshot.agentSession?.workingDirectory, "/tmp/cmux-agent-session-cwd")
    }

    @Test
    func testWorkspaceBusyIndicatorTracksTerminalAgentLifecycleInsteadOfShellCommandLifetime() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        #expect(!workspace.hasActiveAIWork)

        workspace.updatePanelShellActivityState(panelId: panelId, state: .commandRunning)
        #expect(!workspace.hasActiveAIWork)

        workspace.recordAgentPID(
            key: "codex.test-agent",
            pid: 12345,
            panelId: panelId,
            refreshPorts: false
        )
        workspace.setAgentLifecycle(key: "codex", panelId: panelId, lifecycle: .running)
        #expect(workspace.hasActiveAIWork)

        workspace.setAgentLifecycle(key: "codex", panelId: panelId, lifecycle: .needsInput)
        #expect(workspace.hasActiveAIWork)

        workspace.setAgentLifecycle(key: "codex", panelId: panelId, lifecycle: .idle)
        #expect(!workspace.hasActiveAIWork)

        workspace.updatePanelShellActivityState(panelId: panelId, state: .promptIdle)
        #expect(!workspace.hasActiveAIWork)
    }

    @Test
    func testWorkspaceBusyIndicatorTracksVisibleTerminalAgentStatusLine() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        #expect(!workspace.hasActiveAIWork)

        workspace.debugRenderedTerminalRowsForActiveWorkTesting = [
            panelId: [
                "Addressing the workspace tab spinner now.",
                "Working (36s • Esc to interrupt)",
                "",
            ],
        ]
        #expect(workspace.hasActiveAIWork)

        workspace.debugRenderedTerminalRowsForActiveWorkTesting = [
            panelId: [
                "Completed in 36s",
                "",
            ],
        ]
        #expect(!workspace.hasActiveAIWork)
    }

    @Test
    func testWorkspaceBusyIndicatorUsesVisibleStatusLineWhenIdle() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        workspace.debugRenderedTerminalRowsForActiveWorkTesting = [
            panelId: [
                "Working (36s, Esc to interrupt)",
                "",
            ],
        ]
        #expect(workspace.hasActiveAIWork)

        workspace.setAgentLifecycle(key: "codex", panelId: panelId, lifecycle: .idle)

        #expect(workspace.hasActiveAIWork)
    }

    @Test
    func testInterruptingTerminalAgentWorkClearsWorkspaceBusyIndicator() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        workspace.statusEntries["codex"] = SidebarStatusEntry(
            key: "codex",
            value: "Running",
            icon: "bolt.fill",
            color: "#4C8DFF"
        )
        workspace.recordAgentPID(
            key: "codex.test-agent",
            pid: 12345,
            panelId: panelId,
            refreshPorts: false
        )
        workspace.setAgentLifecycle(key: "codex", panelId: panelId, lifecycle: .running)
        workspace.debugRenderedTerminalRowsForActiveWorkTesting = [
            panelId: [
                "Working (36s, Esc to interrupt)",
                "",
            ],
        ]
        #expect(workspace.hasActiveAIWork)

        #expect(workspace.markPanelAgentWorkInterrupted(panelId: panelId))

        #expect(workspace.agentLifecycleStatesByPanelId[panelId]?["codex"] == .idle)
        #expect(workspace.statusEntries["codex"]?.value == "Idle")
        #expect(!workspace.hasActiveAIWork)
    }

    @Test
    func testInterruptMarkerSuppressesStaleVisibleAgentStatusLineUntilNextInput() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        workspace.debugRenderedTerminalRowsForActiveWorkTesting = [
            panelId: [
                "Working (36s, Esc to interrupt)",
                "",
            ],
        ]
        #expect(workspace.hasActiveAIWork)

        #expect(workspace.markPanelAgentWorkInterrupted(panelId: panelId))
        #expect(!workspace.hasActiveAIWork)

        #expect(workspace.clearPanelAgentWorkInterrupt(panelId: panelId))
        #expect(workspace.hasActiveAIWork)
    }

    @Test
    func testWorkspaceBusyIndicatorIgnoresStaleShellStatePanelIds() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)

        workspace.panelShellActivityStates[UUID()] = .commandRunning

        #expect(!workspace.hasActiveAIWork)
    }

    @Test
    func testWorkspaceBusyIndicatorTracksAgentSessionWorkActivity() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let paneId = try #require(workspace.bonsplitController.focusedPaneId)
        let panel = try #require(
            workspace.newAgentSessionSurface(
                inPane: paneId,
                providerID: .codex,
                rendererKind: .react,
                workingDirectory: "/tmp",
                focus: true
            )
        )

        #expect(!workspace.hasActiveAIWork)

        panel.rendererSession.onHasActiveWorkChanged?(true)
        #expect(workspace.hasActiveAIWork)

        panel.rendererSession.onHasActiveWorkChanged?(false)
        #expect(!workspace.hasActiveAIWork)
    }

    @Test
    func testWorkspaceSidebarObservationPublishesWhenAgentPidOwnershipChanges() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        let expectation = XCTestExpectation(description: "sidebar observation emits after PID ownership changes")
        expectation.expectedFulfillmentCount = 2

        var cancellable: AnyCancellable?
        cancellable = workspace.sidebarObservationPublisher.sink { _ in
            expectation.fulfill()
        }
        defer { cancellable?.cancel() }

        workspace.recordAgentPID(
            key: "codex.test-agent",
            pid: 12345,
            panelId: panelId,
            refreshPorts: false
        )

        #expect(XCTWaiter().wait(for: [expectation], timeout: 1.0) == .completed)

        _ = workspace.clearAgentPID(
            key: "codex.test-agent",
            panelId: panelId,
            clearStatus: false,
            refreshPorts: false
        )
    }

    @Test
    func testWorkspaceSidebarObservationPublishesWhenAgentLifecycleChanges() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let panelId = try #require(workspace.focusedPanelId)

        let expectation = XCTestExpectation(description: "sidebar observation emits after agent lifecycle changes")
        expectation.expectedFulfillmentCount = 2

        var cancellable: AnyCancellable?
        cancellable = workspace.sidebarObservationPublisher.sink { _ in
            expectation.fulfill()
        }
        defer { cancellable?.cancel() }

        workspace.setAgentLifecycle(key: "codex", panelId: panelId, lifecycle: .running)

        #expect(XCTWaiter().wait(for: [expectation], timeout: 1.0) == .completed)
    }

    @Test
    func testAgentSessionProcessStoreClearsBusyWhenLastActivityCompletes() {
        let store = AgentSessionProcessStore()

        #expect(!store.hasActiveWork)

        store.ingestActivityForTesting(activityID: "command-1", status: "inProgress")
        #expect(store.hasActiveWork)

        store.markTurnCompleteForTesting()
        #expect(!store.hasActiveWork)

        store.ingestActivityForTesting(activityID: "command-1", status: "inProgress")
        #expect(store.hasActiveWork)

        store.ingestActivityForTesting(activityID: "command-1", status: "completed")
        #expect(!store.hasActiveWork)
    }

    @Test
    func testAgentSessionProcessStorePersistsRawActivityOutput() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-agent-session-raw-output-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let rawOutputStore = ChatRawTerminalOutputFileStore(rootDirectory: directory)
        let store = AgentSessionProcessStore(rawOutputStore: rawOutputStore)

        let metadata = store.ingestRawActivityOutputForTesting(
            sessionId: "session-1",
            activityID: "command-1",
            command: "echo ok",
            outputDelta: "ok\n"
        )
        guard let rawOutputRef = metadata?["rawOutputRef"] as? String else {
            Issue.record("Expected a raw output reference")
            return
        }

        var record: ChatRawTerminalOutputRecord?
        for _ in 0..<10 {
            record = try await store.readRawActivityOutput(rawOutputRef: rawOutputRef)
            if record != nil { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(record?.command == "echo ok")
        #expect(record?.rawOutput == "ok\n")
        #expect(record?.metadata.rawOutputRef == rawOutputRef)
    }
}
