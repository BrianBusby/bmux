import Foundation
import ProvenanceEngineContracts

/// Acquires bounded transcript chunks and persists only acknowledged line positions.
actor CLIProvenanceCodexTranscriptTailer {
    struct Outcome {
        let importResult: CLIProvenanceCodexTranscriptImporter.LiveImportResult
        let cursorPersisted: Bool
        let cursorWriteFailed: Bool
        let unreadBytes: UInt64
        let offset: UInt64
    }

    private let providerSessionID: String
    private let workspaceID: String?
    private let surfaceID: String?
    private let importer: CLIProvenanceCodexTranscriptImporter
    private let replayImporter: CLIProvenanceCodexTranscriptImporter
    private let cursorStore: CLIProvenanceCodexTranscriptCursorStore
    private var activePath: String?
    private var state: CLIProvenanceCodexTranscriptImporter.LiveImportState?
    private var persistedOffset: UInt64 = 0
    private var monitorStatus: CLIProvenanceCodexTranscriptMonitorStatus?

    init(providerSessionID: String, workspaceID: String?, surfaceID: String?,
         client: any ProvenanceEngineClient,
         cursorStore: CLIProvenanceCodexTranscriptCursorStore) {
        self.providerSessionID = providerSessionID
        self.workspaceID = workspaceID
        self.surfaceID = surfaceID
        importer = CLIProvenanceCodexTranscriptImporter(client: client)
        replayImporter = CLIProvenanceCodexTranscriptImporter(client: client, emitsEvents: false)
        self.cursorStore = cursorStore
    }

    func consume(at url: URL) async throws -> Outcome {
        let path = url.standardizedFileURL.path
        if activePath != path || state == nil {
            state = try await restoredState(at: url)
            activePath = path
        }
        var workingState = state ?? freshState()
        let previousIdentity = workingState.fileIdentity
        let previousReadOffset = workingState.offset
        let result = try await importer.importLiveTranscriptAppend(at: url, state: &workingState)
        if let previousIdentity, let currentIdentity = workingState.fileIdentity,
           !previousIdentity.matches(currentIdentity) || workingState.offset < previousReadOffset {
            persistedOffset = 0
        }
        state = workingState

        var cursorPersisted = false
        var cursorWriteFailed = false
        if let identity = workingState.fileIdentity,
           workingState.metadata?.sessionID == providerSessionID,
           workingState.lastCompletedLineOffset > persistedOffset {
            let cursor = CLIProvenanceCodexTranscriptCursor(
                providerSessionID: providerSessionID, sourcePath: path,
                fileIdentity: identity,
                byteOffset: workingState.lastCompletedLineOffset,
                lineNumber: workingState.nextLineNumber - 1,
                updatedAt: Date()
            )
            do {
                try await cursorStore.save(cursor)
                persistedOffset = cursor.byteOffset
                cursorPersisted = true
            } catch {
                cursorWriteFailed = true
            }
        }
        let fileSize = (try? CLIProvenanceCodexTranscriptFileIdentity.inspect(url).size)
            ?? workingState.offset
        let unreadBytes = fileSize > workingState.lastCompletedLineOffset
            ? fileSize - workingState.lastCompletedLineOffset : 0
        var status = await currentStatus()
        status.cursorOffset = persistedOffset
        status.readOffset = workingState.offset
        status.unreadBytes = unreadBytes
        status.firstBacklogAt = unreadBytes > 0
            ? (cursorPersisted ? Date() : (status.firstBacklogAt ?? Date())) : nil
        status.skippedLines = status.skippedLines.addingReportingOverflow(result.skippedLines).overflow
            ? Int.max : status.skippedLines + result.skippedLines
        status.retrying = cursorWriteFailed
        status.lastErrorKind = cursorWriteFailed ? "cursor_write" : nil
        if cursorPersisted { status.lastProgressAt = Date() }
        status.updatedAt = Date()
        monitorStatus = status
        try? await cursorStore.saveStatus(status)
        return Outcome(importResult: result, cursorPersisted: cursorPersisted,
                       cursorWriteFailed: cursorWriteFailed,
                       unreadBytes: unreadBytes, offset: workingState.offset)
    }

    func recordFailure(kind: String) async {
        var status = await currentStatus()
        status.appendFailures = status.appendFailures == Int.max ? Int.max : status.appendFailures + 1
        status.retrying = true
        status.lastErrorKind = String(kind.prefix(64))
        status.updatedAt = Date()
        monitorStatus = status
        try? await cursorStore.saveStatus(status)
    }

    func finish(path: String) async throws -> CLIProvenanceCodexTranscriptImporter.FileReport {
        guard var workingState = state else {
            return CLIProvenanceCodexTranscriptImporter.FileReport(path: path, status: "live-finished")
        }
        let report = try await importer.finishLiveTranscriptImport(state: &workingState, path: path)
        state = workingState
        return report
    }

    func reset() {
        state = nil
        activePath = nil
        persistedOffset = 0
    }

    private func currentStatus() async -> CLIProvenanceCodexTranscriptMonitorStatus {
        if let monitorStatus { return monitorStatus }
        return (try? await cursorStore.loadStatus(providerSessionID: providerSessionID))
            ?? CLIProvenanceCodexTranscriptMonitorStatus(providerSessionID: providerSessionID)
    }

    private func restoredState(at url: URL) async throws
        -> CLIProvenanceCodexTranscriptImporter.LiveImportState {
        persistedOffset = 0
        let source = try CLIProvenanceCodexTranscriptFileIdentity.inspect(url)
        guard let cursor = try? await cursorStore.load(providerSessionID: providerSessionID),
              cursor.matches(sessionID: providerSessionID, url: url,
                             fileIdentity: source.identity, fileSize: source.size),
              cursor.byteOffset > 0 else { return freshState() }

        var restored = freshState()
        do {
            while restored.offset < cursor.byteOffset {
                let remaining = cursor.byteOffset - restored.offset
                let limit = Int(min(remaining, UInt64(CLIProvenanceCodexTranscriptImporter.liveReadLimit)))
                let before = restored.offset
                _ = try await replayImporter.importLiveTranscriptAppend(
                    at: url, state: &restored, readLimit: limit
                )
                guard restored.offset > before,
                      restored.fileIdentity.map({ $0.matches(source.identity) }) == true else {
                    return freshState()
                }
            }
            guard restored.offset == cursor.byteOffset,
                  restored.lastCompletedLineOffset == cursor.byteOffset,
                  restored.nextLineNumber - 1 == cursor.lineNumber,
                  restored.metadata?.sessionID == providerSessionID else {
                return freshState()
            }
            persistedOffset = cursor.byteOffset
            return restored
        } catch {
            return freshState()
        }
    }

    private func freshState() -> CLIProvenanceCodexTranscriptImporter.LiveImportState {
        CLIProvenanceCodexTranscriptImporter.LiveImportState(
            workspaceID: workspaceID, surfaceID: surfaceID,
            expectedSessionID: providerSessionID
        )
    }
}
