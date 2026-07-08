import Foundation
@testable import BmuxTerminal

final class FakeHibernationRecorder: AgentHibernationRecording {
    func recordTerminalInput(workspaceId: UUID, panelId: UUID) {}
    func recordTerminalInterrupt(workspaceId: UUID, panelId: UUID) {}
}
