import Foundation
import ProvenanceEngineContracts

struct CLIProvenanceCodexTranscriptImporter {
    static let defaultTranscriptPath = "~/.codex/sessions"

    static let textLimit = 12_000
    static let summaryLimit = 4_000
    static let transcriptOrigin = ProvenanceEvidenceOrigin(rawValue: "codex-transcript")
    static let localEvidenceScope = ProvenanceEvidenceScope(level: .personal, id: "bmux-local")

    let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    let stableIDFactory = StableIDFactory()

    init(client: any ProvenanceEngineContracts.ProvenanceEngineClient) {
        self.client = client
    }

    func importTranscripts(path rawPath: String?, limit: Int? = nil) async throws -> Report {
        let trimmedPath = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmedPath?.isEmpty == false ? trimmedPath ?? Self.defaultTranscriptPath : Self.defaultTranscriptPath
        let rootURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL
        let transcriptURLs = try transcriptFiles(at: rootURL)
        let selectedURLs = limit.map { Array(transcriptURLs.prefix($0)) } ?? transcriptURLs

        var report = Report(path: rootURL.path, filesVisited: selectedURLs.count)
        for url in selectedURLs {
            do {
                report.merge(try await importTranscript(at: url))
            } catch {
                report.recordError(path: url.path, message: Self.bounded(String(describing: error), limit: 512))
            }
        }
        return report
    }

    private func transcriptFiles(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ImportError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.error.pathMissing",
                    defaultValue: "Codex transcript path does not exist: %@"
                ),
                url.path
            ))
        }
        if !isDirectory.boolValue {
            return url.pathExtension == "jsonl" ? [url] : []
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ImportError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.error.pathUnreadable",
                    defaultValue: "Codex transcript path is not readable: %@"
                ),
                url.path
            ))
        }
        var urls: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                urls.append(fileURL.standardizedFileURL)
            }
        }
        return urls.sorted { $0.path < $1.path }
    }

    private func importTranscript(at url: URL) async throws -> FileReport {
        let lines = try transcriptLines(at: url)
        guard let metadata = sessionMetadata(from: lines) else {
            return FileReport(path: url.path, status: "skipped", skippedReason: "missing_session_metadata")
        }

        var context = TranscriptContext(
            sessionID: metadata.sessionID,
            providerThreadID: metadata.providerThreadID,
            cwd: metadata.cwd,
            sessionStartedAt: metadata.timestamp,
            latestModel: metadata.model
        )
        var fileReport = FileReport(path: url.path, status: "imported")

        try await appendThread(metadata: metadata, line: metadata.line, fileReport: &fileReport)

        for line in lines {
            try await importLine(line, metadata: metadata, context: &context, fileReport: &fileReport)
        }

        for pendingPrompt in context.pendingPrompts {
            try await appendPrompt(
                metadata: metadata,
                line: pendingPrompt.line,
                text: pendingPrompt.text,
                providerTurnID: nil,
                fileReport: &fileReport
            )
        }

        return fileReport
    }

    func importLiveTranscriptAppend(at url: URL, state: inout LiveImportState) async throws -> LiveImportResult {
        let path = url.standardizedFileURL.path
        var fileReport = FileReport(path: path, status: "live")
        let fileSize = try currentFileSize(at: url)
        if fileSize < state.offset {
            state = LiveImportState()
        }

        guard fileSize > state.offset else {
            return LiveImportResult(
                fileReport: fileReport,
                consumedLines: 0,
                retainedPartialLine: !state.pendingFragment.isEmpty,
                metadataAvailable: state.metadata != nil
            )
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: state.offset)
        let appendedData = handle.readDataToEndOfFile()
        state.offset += UInt64(appendedData.count)

        let lines = try completedTranscriptLines(
            from: appendedData,
            path: path,
            state: &state
        )
        try await importLiveTranscriptLines(lines, state: &state, fileReport: &fileReport)
        return LiveImportResult(
            fileReport: fileReport,
            consumedLines: lines.count,
            retainedPartialLine: !state.pendingFragment.isEmpty,
            metadataAvailable: state.metadata != nil
        )
    }

    func finishLiveTranscriptImport(state: inout LiveImportState, path: String) async throws -> FileReport {
        var fileReport = FileReport(path: path, status: "live-finished")
        guard let metadata = state.metadata,
              var context = state.context,
              !context.pendingPrompts.isEmpty else {
            return fileReport
        }
        let pendingPrompts = context.pendingPrompts
        context.pendingPrompts = []
        for pendingPrompt in pendingPrompts {
            try await appendPrompt(
                metadata: metadata,
                line: pendingPrompt.line,
                text: pendingPrompt.text,
                providerTurnID: nil,
                fileReport: &fileReport
            )
        }
        state.context = context
        return fileReport
    }

    private func currentFileSize(at url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func completedTranscriptLines(
        from appendedData: Data,
        path: String,
        state: inout LiveImportState
    ) throws -> [TranscriptLine] {
        guard !appendedData.isEmpty else { return [] }
        var buffer = state.pendingFragment
        buffer.append(appendedData)
        var lines: [TranscriptLine] = []
        let bytes = [UInt8](buffer)
        var lineStart = 0
        for index in bytes.indices where bytes[index] == 0x0a {
            let lineData = Data(bytes[lineStart..<index])
            if let lineText = String(data: lineData, encoding: .utf8),
               let line = try transcriptLine(
                   from: lineText,
                   lineNumber: state.nextLineNumber,
                   path: path
               ) {
                lines.append(line)
            } else if !lineData.isEmpty {
                throw ImportError(message: String.localizedStringWithFormat(
                    String(
                        localized: "cli.provenance.import.error.invalidUTF8Line",
                        defaultValue: "Codex transcript line is not valid UTF-8: %@:%d"
                    ),
                    path,
                    state.nextLineNumber
                ))
            }
            state.nextLineNumber += 1
            lineStart = index + 1
        }
        state.pendingFragment = lineStart < bytes.count ? Data(bytes[lineStart..<bytes.count]) : Data()
        return lines
    }

    private func importLiveTranscriptLines(
        _ lines: [TranscriptLine],
        state: inout LiveImportState,
        fileReport: inout FileReport
    ) async throws {
        guard !lines.isEmpty else { return }
        if state.metadata == nil {
            state.pendingLines.append(contentsOf: lines)
            guard let metadata = sessionMetadata(from: state.pendingLines) else { return }
            state.metadata = metadata
            state.context = TranscriptContext(
                sessionID: metadata.sessionID,
                providerThreadID: metadata.providerThreadID,
                cwd: metadata.cwd,
                sessionStartedAt: metadata.timestamp,
                latestModel: metadata.model
            )
        } else {
            state.pendingLines.append(contentsOf: lines)
        }

        guard let metadata = state.metadata,
              var context = state.context else { return }
        if !state.threadObserved {
            try await appendThread(metadata: metadata, line: metadata.line, fileReport: &fileReport)
            state.threadObserved = true
        }
        let importLines = state.pendingLines
        state.pendingLines = []
        for line in importLines {
            try await importLine(line, metadata: metadata, context: &context, fileReport: &fileReport)
        }
        state.context = context
    }

    private func importLine(
        _ line: TranscriptLine,
        metadata: TranscriptMetadata,
        context: inout TranscriptContext,
        fileReport: inout FileReport
    ) async throws {
        switch line.type {
        case "turn_context":
            context.cwd = Self.firstNonEmpty(Self.string(line.payload["cwd"]), context.cwd)
            context.latestModel = Self.firstNonEmpty(Self.string(line.payload["model"]), context.latestModel)
        case "event_msg":
            try await importEventMessage(line, metadata: metadata, context: &context, fileReport: &fileReport)
        case "response_item":
            try await importResponseItem(line, metadata: metadata, context: &context, fileReport: &fileReport)
        default:
            return
        }
    }

    private func importEventMessage(
        _ line: TranscriptLine,
        metadata: TranscriptMetadata,
        context: inout TranscriptContext,
        fileReport: inout FileReport
    ) async throws {
        switch Self.string(line.payload["type"]) {
        case "task_started":
            guard let providerTurnID = Self.trimmedNonEmpty(Self.string(line.payload["turn_id"])) else { return }
            context.currentProviderTurnID = providerTurnID
            try await appendTurn(
                metadata: metadata,
                line: line,
                providerTurnID: providerTurnID,
                status: "started",
                model: context.latestModel,
                startedAt: Self.dateFromSeconds(line.payload["started_at"]) ?? line.timestamp,
                completedAt: nil,
                fileReport: &fileReport
            )
            context.observedProviderTurnIDs.insert(providerTurnID)
            let pendingPrompts = context.pendingPrompts
            context.pendingPrompts = []
            for prompt in pendingPrompts {
                try await appendPrompt(
                    metadata: metadata,
                    line: prompt.line,
                    text: prompt.text,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            }
        case "item_completed":
            guard let item = Self.dictionary(line.payload["item"]),
                  let itemType = Self.string(item["type"]) else {
                return
            }
            let providerTurnID = Self.firstNonEmpty(
                Self.string(line.payload["turn_id"]),
                context.currentProviderTurnID
            )
            if let providerTurnID {
                try await ensureTurnObserved(
                    metadata: metadata,
                    line: line,
                    context: &context,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            }
            if itemType == "CommandExecution" {
                try await appendCommand(
                    metadata: metadata,
                    line: line,
                    item: item,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            } else if itemType == "Reasoning" {
                try await appendReasoningSummary(
                    metadata: metadata,
                    line: line,
                    item: item,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            }
        default:
            return
        }
    }

    private func importResponseItem(
        _ line: TranscriptLine,
        metadata: TranscriptMetadata,
        context: inout TranscriptContext,
        fileReport: inout FileReport
    ) async throws {
        let itemType = Self.string(line.payload["type"])
        if itemType == "message",
           Self.string(line.payload["role"]) == "user",
           let text = Self.messageText(from: line.payload) {
            let providerTurnID = Self.firstNonEmpty(Self.turnID(from: line.payload), context.currentProviderTurnID)
            if let providerTurnID {
                try await ensureTurnObserved(
                    metadata: metadata,
                    line: line,
                    context: &context,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
                try await appendPrompt(
                    metadata: metadata,
                    line: line,
                    text: text,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            } else {
                context.pendingPrompts.append(PendingPrompt(line: line, text: text))
            }
            return
        }

        if itemType == "function_call",
           Self.string(line.payload["name"]) == "update_plan",
           let plan = Self.planUpdate(from: line.payload) {
            let providerTurnID = Self.firstNonEmpty(Self.turnID(from: line.payload), context.currentProviderTurnID)
            if let providerTurnID {
                try await ensureTurnObserved(
                    metadata: metadata,
                    line: line,
                    context: &context,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            }
            try await appendPlan(
                metadata: metadata,
                line: line,
                plan: plan,
                providerTurnID: providerTurnID,
                fileReport: &fileReport
            )
            return
        }

        if itemType == "reasoning",
           let text = Self.reasoningText(from: line.payload) {
            let providerTurnID = Self.firstNonEmpty(Self.turnID(from: line.payload), context.currentProviderTurnID)
            if let providerTurnID {
                try await ensureTurnObserved(
                    metadata: metadata,
                    line: line,
                    context: &context,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            }
            try await appendReasoningSummary(
                metadata: metadata,
                line: line,
                itemID: Self.firstNonEmpty(Self.string(line.payload["id"]), Self.string(line.payload["call_id"])),
                text: text,
                providerTurnID: providerTurnID,
                fileReport: &fileReport
            )
            return
        }

        if itemType == "custom_tool_call",
           Self.string(line.payload["name"]) == "apply_patch",
           Self.string(line.payload["status"]) != "failed",
           let patch = Self.string(line.payload["input"]) {
            let paths = Self.patchFileChanges(from: patch)
            guard !paths.isEmpty else { return }
            let providerTurnID = Self.firstNonEmpty(Self.turnID(from: line.payload), context.currentProviderTurnID)
            if let providerTurnID {
                try await ensureTurnObserved(
                    metadata: metadata,
                    line: line,
                    context: &context,
                    providerTurnID: providerTurnID,
                    fileReport: &fileReport
                )
            }
            try await appendFileChangeAttribution(
                metadata: metadata,
                line: line,
                operationID: Self.firstNonEmpty(Self.string(line.payload["call_id"]), Self.string(line.payload["id"])),
                changes: paths,
                providerTurnID: providerTurnID,
                fileReport: &fileReport
            )
        }
    }
}
