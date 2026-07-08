import Foundation
@testable import CmuxTerminal

final class FakeHibernationRecorder: AgentHibernationRecording {
    func recordTerminalInput(workspaceId: UUID, panelId: UUID) {}
    func recordTerminalInterrupt(workspaceId: UUID, panelId: UUID) {}
}
