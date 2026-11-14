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
        let needsAttention = stale || status?.retrying == true || status?.lastErrorKind != nil || (status?.skippedLines ?? 0) > 0 || (lagSeconds ?? 0) > 300
        let reportFreshness = status == nil ? "unavailable" : (stale ? "stale" : "recent")
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "provider_session_id": sessionID,
            "available": status != nil,
            "report_freshness": reportFreshness,
            "cursor_currentness": "unknown",
            "observation_health": "unknown",
            "cursor_offset": status?.cursorOffset as Any? ?? NSNull(),
            "read_offset": status?.readOffset as Any? ?? NSNull(),
            "unread_bytes": status?.unreadBytes as Any? ?? NSNull(),
            "skipped_lines": status?.skippedLines as Any? ?? NSNull(),
            "append_or_read_failures": status?.appendFailures as Any? ?? NSNull(),
            "retrying": status?.retrying as Any? ?? NSNull(),
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
        let summary: String
        if let status {
            summary = String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.diagnostics.codexTranscript.summary",
                    defaultValue: "Codex transcript %@: cursor %llu, unread %llu bytes, skipped %d lines, failures %d"
                ),
                sessionID, status.cursorOffset, status.unreadBytes, status.skippedLines, status.appendFailures
            )
        } else {
            summary = String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.diagnostics.codexTranscript.noReport",
                    defaultValue: "No retained monitor report for Codex transcript %@"
                ),
                sessionID
            )
        }
        let health = needsAttention
            ? String(localized: "cli.provenance.diagnostics.codexTranscript.attention",
                     defaultValue: "Needs attention: the last report is unavailable, stale, retrying, has an error or skipped lines, or has a backlog over five minutes old")
            : String(localized: "cli.provenance.diagnostics.codexTranscript.reportRecent",
                     defaultValue: "Last monitor report: no current error or retry, skipped lines, or prolonged backlog reported")
        let uncertainty = String(
            localized: "cli.provenance.diagnostics.codexTranscript.observationUnknown",
            defaultValue: "Current cursor position and observation connection are unknown"
        )
        print(summary + "\n" + health + "\n" + uncertainty)
    }
}
