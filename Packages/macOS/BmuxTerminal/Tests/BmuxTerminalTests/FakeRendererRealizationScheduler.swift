@testable import BmuxTerminal

final class FakeRendererRealizationScheduler: TerminalRendererRealizationScheduling {
    @MainActor
    func scheduleImmediatePass() {}
}
