@testable import BmuxTerminal

@MainActor
final class ManualRestoreSpawnDelay: TerminalSurfaceRestoreSpawnDelayCancelling {
    func cancel() {}
}
