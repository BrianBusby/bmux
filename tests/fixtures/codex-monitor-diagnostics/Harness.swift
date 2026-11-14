import Foundation

struct CLIError: Error { let message: String }
struct BMUXCLI {
    func jsonString(_ object: Any) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
    }
}

@main struct Harness {
    static func main() async throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TEST_STATE_DIR"]!, isDirectory: true)
        let store = CLIProvenanceCodexTranscriptCursorStore(directoryURL: directory.appendingPathComponent("codex-transcript-cursors"))
        let mode = CommandLine.arguments[1]
        if mode != "missing" {
            var status = CLIProvenanceCodexTranscriptMonitorStatus(providerSessionID: "synthetic-session")
            status.cursorOffset = 10
            status.readOffset = 15
            status.unreadBytes = ["backlog", "long-backlog"].contains(mode) ? 5 : 0
            status.skippedLines = mode == "skipped" ? 1 : 0
            status.firstBacklogAt = mode == "backlog" ? Date() : (mode == "long-backlog" ? Date().addingTimeInterval(-600) : nil)
            status.retrying = mode == "retrying"
            status.lastErrorKind = mode == "error" ? "synthetic" : nil
            if mode == "stale" { status.updatedAt = Date().addingTimeInterval(-600) }
            try await store.saveStatus(status)
        }
        try await BMUXCLI().runProvenanceCodexTranscriptDiagnostics(commandArgs: ["synthetic-session"], jsonOutput: CommandLine.arguments.contains("--json"), databasePath: nil)
    }
}
