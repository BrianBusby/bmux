import Foundation
import BmuxSettings

extension BMUXCLI {
    func runProvenanceCodexTranscriptDiagnostics(
        commandArgs: [String], jsonOutput: Bool, databasePath: String?
    ) async throws {
        let usage = String(
            localized: "cli.provenance.diagnostics.codexTranscript.usage",
            defaultValue: "Usage: bmux provenance diagnostics codex-transcript <provider-session-id> [--json]"
        )
        guard databasePath == nil, commandArgs.count == 1,
              let sessionID = commandArgs.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionID.isEmpty, !sessionID.hasPrefix("-") else {
            throw CLIError(message: usage)
        }
        let directory = BmuxStateDirectory.url(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        ).appendingPathComponent("codex-transcript-cursors", isDirectory: true)
        let store = CLIProvenanceCodexTranscriptCursorStore(directoryURL: directory)
        let status = try await store.loadStatus(providerSessionID: sessionID)
        let now = Date()
        let lagSeconds = status?.firstBacklogAt.map { max(0, Int(now.timeIntervalSince($0))) }
        let stale = status.map { now.timeIntervalSince($0.updatedAt) > 300 } ?? true
        let needsAttention = stale || status?.retrying == true || (lagSeconds ?? 0) > 300
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "provider_session_id": sessionID,
            "available": status != nil,
            "cursor_offset": status?.cursorOffset ?? 0,
            "read_offset": status?.readOffset ?? 0,
            "unread_bytes": status?.unreadBytes ?? 0,
            "skipped_lines": status?.skippedLines ?? 0,
            "append_or_read_failures": status?.appendFailures ?? 0,
            "retrying": status?.retrying ?? false,
            "last_error_kind": status?.lastErrorKind as Any? ?? NSNull(),
            "last_progress_at": status?.lastProgressAt.map { formatter.string(from: $0) } as Any? ?? NSNull(),
            "last_checked_at": status.map { formatter.string(from: $0.updatedAt) } as Any? ?? NSNull(),
            "ingestion_lag_seconds": lagSeconds as Any? ?? NSNull(),
            "needs_attention": needsAttention
        ]
        if jsonOutput {
            print(jsonString(payload))
            return
        }
        let summary = String.localizedStringWithFormat(
            String(
                localized: "cli.provenance.diagnostics.codexTranscript.summary",
                defaultValue: "Codex transcript %@: cursor %llu, unread %llu bytes, skipped %d lines, failures %d"
            ),
            sessionID, status?.cursorOffset ?? 0, status?.unreadBytes ?? 0,
            status?.skippedLines ?? 0, status?.appendFailures ?? 0
        )
        let health = needsAttention
            ? String(localized: "cli.provenance.diagnostics.codexTranscript.attention",
                     defaultValue: "Needs attention: retrying, stale, or more than five minutes behind")
            : String(localized: "cli.provenance.diagnostics.codexTranscript.healthy",
                     defaultValue: "Healthy: cursor is current")
        print(summary + "\n" + health)
    }
}
