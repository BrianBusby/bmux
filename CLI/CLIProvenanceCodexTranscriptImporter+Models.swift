import CryptoKit
import Foundation
import ProvenanceEngineContracts

extension CLIProvenanceCodexTranscriptImporter {
    struct Report: Equatable {
        let path: String
        var filesVisited: Int
        var filesImported: Int = 0
        var filesSkipped: Int = 0
        var fileErrors: [FileError] = []
        var eventsAppended: Int = 0
        var duplicateEvents: Int = 0
        var threads: Int = 0
        var turns: Int = 0
        var prompts: Int = 0
        var plans: Int = 0
        var commands: Int = 0
        var reasoningSummaries: Int = 0
        var assistantMessages: Int = 0
        var fileChanges: Int = 0

        var payload: [String: Any] {
            [
                "path": path,
                "files": [
                    "visited": filesVisited,
                    "imported": filesImported,
                    "skipped": filesSkipped,
                    "errors": fileErrors.map(\.payload)
                ],
                "events": [
                    "appended": eventsAppended,
                    "duplicates": duplicateEvents
                ],
                "evidence": [
                    "threads": threads,
                    "turns": turns,
                    "prompts": prompts,
                    "plans": plans,
                    "commands": commands,
                    "reasoning_summaries": reasoningSummaries,
                    "assistant_messages": assistantMessages,
                    "file_changes": fileChanges
                ]
            ]
        }

        mutating func merge(_ fileReport: FileReport) {
            if fileReport.status == "skipped" {
                filesSkipped += 1
            } else {
                filesImported += 1
            }
            eventsAppended += fileReport.eventsAppended
            duplicateEvents += fileReport.duplicateEvents
            threads += fileReport.threads
            turns += fileReport.turns
            prompts += fileReport.prompts
            plans += fileReport.plans
            commands += fileReport.commands
            reasoningSummaries += fileReport.reasoningSummaries
            assistantMessages += fileReport.assistantMessages
            fileChanges += fileReport.fileChanges
        }

        mutating func recordError(path: String, message: String) {
            fileErrors.append(FileError(path: path, message: message))
        }
    }

    struct FileError: Equatable {
        let path: String
        let message: String

        var payload: [String: Any] {
            [
                "path": path,
                "message": message
            ]
        }
    }

    struct FileReport: Equatable {
        let path: String
        var status: String
        var skippedReason: String?
        var eventsAppended: Int = 0
        var duplicateEvents: Int = 0
        var threads: Int = 0
        var turns: Int = 0
        var prompts: Int = 0
        var plans: Int = 0
        var commands: Int = 0
        var reasoningSummaries: Int = 0
        var assistantMessages: Int = 0
        var fileChanges: Int = 0
    }

    struct LiveImportResult: Equatable {
        let fileReport: FileReport
        let consumedLines: Int
        let retainedPartialLine: Bool
        let metadataAvailable: Bool
    }

    struct LiveImportState {
        var offset: UInt64 = 0
        var pendingFragment = Data()
        var nextLineNumber = 1
        var metadata: TranscriptMetadata?
        var context: TranscriptContext?
        var pendingLines: [TranscriptLine] = []
        var threadObserved = false
    }

    struct TranscriptLine {
        let lineNumber: Int
        let ordinal: Int?
        let type: String
        let timestamp: Date?
        let payload: [String: Any]
    }

    struct TranscriptMetadata {
        let line: TranscriptLine
        let sessionID: String
        let providerThreadID: String
        let cwd: String?
        let timestamp: Date
        let model: String?
        let effort: String?
    }

    struct TranscriptContext {
        let sessionID: String
        let providerThreadID: String
        var cwd: String?
        let sessionStartedAt: Date
        var latestModel: String?
        var latestEffort: String?
        var currentProviderTurnID: String?
        var lastCompletedProviderTurnID: String?
        var observedProviderTurnIDs: Set<String> = []
        var startedProviderTurnIDs: Set<String> = []
        var pendingPrompts: [PendingPrompt] = []
    }

    struct PendingPrompt {
        let line: TranscriptLine
        let text: String
    }

    struct PlanUpdate {
        let explanation: String?
        let steps: [PlanStep]
    }

    struct PlanStep {
        let text: String
        let status: String
    }

    struct PatchFileChange {
        let path: String
        let status: String
    }

    struct GitContext {
        let repositoryID: String
        let worktreeID: String
        let repository: ProvenanceRepositoryRecord
        let worktree: ProvenanceWorktreeRecord
    }

    struct GitSnapshot {
        let repositoryRoot: String
        let commonDirectory: String?
        let remoteSlug: String?
        let branch: String?
        let headCommit: String?
        let isDirty: Bool
    }

    struct ImportError: Error, CustomStringConvertible {
        let message: String

        var description: String {
            message
        }
    }

    struct StableIDFactory {
        func repositoryID(repositoryRoot: String) -> String {
            id(prefix: "repository", value: normalizedPath(repositoryRoot))
        }

        func worktreeID(repositoryRoot: String) -> String {
            id(prefix: "worktree", value: normalizedPath(repositoryRoot))
        }

        func fileChangeID(worktreeID: String, path: String) -> String {
            id(prefix: "file", value: "\(worktreeID)\n\(path)")
        }

        func changeSetID(worktreeID: String, fingerprint: String) -> String {
            id(prefix: "changeset", value: "\(worktreeID)\n\(fingerprint)")
        }

        func id(prefix: String, value: String) -> String {
            "\(prefix)-\(digest(value).prefix(24))"
        }

        private func digest(_ value: String) -> String {
            let hash = SHA256.hash(data: Data(value.utf8))
            return hash.map { String(format: "%02x", $0) }.joined()
        }

        private func normalizedPath(_ path: String) -> String {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            return URL(fileURLWithPath: trimmed).standardizedFileURL.path
        }
    }
}
