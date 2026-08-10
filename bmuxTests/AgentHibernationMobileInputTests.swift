import Foundation
import XCTest
import BMUXMobileCore
import BmuxTerminal

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
final class AgentHibernationMobileInputTests: XCTestCase {
    func testMobileTerminalInputToHibernatedTerminalQueuesAndPreparesResume() async throws {
        let previousManager = TerminalController.shared.activeTabManagerForCallerNotification()
        let manager = TabManager()
        TerminalController.shared.setActiveTabManager(manager)
        defer {
            TerminalController.shared.setActiveTabManager(previousManager)
        }

        let workspace = try XCTUnwrap(manager.selectedWorkspace)
        let panelId = try XCTUnwrap(workspace.focusedPanelId)
        let panel = try XCTUnwrap(workspace.panels[panelId] as? TerminalPanel)
        let snapshot = SessionRestorableAgentSnapshot(
            kind: .codex,
            sessionId: "codex-mobile-input-resume",
            workingDirectory: "/tmp/bmux-agent-hibernation",
            launchCommand: launch("codex", "/usr/local/bin/codex", cwd: "/tmp/bmux-agent-hibernation")
        )

        workspace.enterAgentHibernation(
            panelId: panelId,
            agent: snapshot,
            lastActivityAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertTrue(panel.isAgentHibernated)
        XCTAssertEqual(workspace.restoredAgentResumeStatesByPanelId[panelId], .manualResumeAvailable)

        let response = await TerminalController.shared.mobileHostHandleRPC(
            MobileHostRPCRequest(
                id: "mobile-input",
                method: "terminal.input",
                params: [
                    "workspace_id": workspace.id.uuidString,
                    "surface_id": panelId.uuidString,
                    "text": "pwd",
                ],
                auth: nil
            )
        )

        guard case let .ok(rawPayload) = response,
              let payload = rawPayload as? [String: Any] else {
            XCTFail("Expected mobile terminal input to succeed")
            return
        }
        XCTAssertEqual(payload["queued"] as? Bool, true)
        XCTAssertFalse(panel.isAgentHibernated)
        XCTAssertEqual(workspace.restoredAgentResumeStatesByPanelId[panelId], .awaitingAutoResumeCommand)
    }

    private func launch(
        _ launcher: String,
        _ executablePath: String,
        arguments: [String] = [],
        cwd: String
    ) -> AgentLaunchCommandSnapshot {
        AgentLaunchCommandSnapshot(
            launcher: launcher,
            executablePath: executablePath,
            arguments: arguments.isEmpty ? [executablePath] : arguments,
            workingDirectory: cwd,
            environment: nil,
            capturedAt: nil,
            source: nil
        )
    }
}
