import Foundation

extension CLIProvenanceCodexTranscriptImporter {
    static let liveReadLimit = 64 * 1_024
    static let liveLineLimit = 4 * 1_024 * 1_024
    static let livePendingLineLimit = 64

    func importLiveTranscriptAppend(
        at url: URL,
        state: inout LiveImportState,
        readLimit: Int = 65_536
    ) async throws -> LiveImportResult {
        let path = url.standardizedFileURL.path
        var fileReport = FileReport(path: path, status: "live")
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let source = try CLIProvenanceCodexTranscriptFileIdentity.inspect(handle)
        let fileSize = source.size
        if fileSize < state.offset ||
            (state.fileIdentity.map { !$0.matches(source.identity) } ?? false) {
            state = LiveImportState(
                workspaceID: state.workspaceID, surfaceID: state.surfaceID,
                expectedSessionID: state.expectedSessionID
            )
        }
        state.fileIdentity = source.identity

        guard fileSize > state.offset else {
            return LiveImportResult(
                fileReport: fileReport,
                consumedLines: 0,
                skippedLines: 0,
                retainedPartialLine: !state.pendingFragment.isEmpty,
                metadataAvailable: state.metadata != nil,
                hasMoreData: false
            )
        }

        let startOffset = state.offset
        try handle.seek(toOffset: startOffset)
        let boundedCount = Int(min(UInt64(max(1, min(readLimit, Self.liveReadLimit))),
                                   fileSize - startOffset))
        let appendedData = try handle.read(upToCount: boundedCount) ?? Data()
        let nextOffset = startOffset + UInt64(appendedData.count)

        var workingState = state
        let parsed = completedTranscriptLines(
            from: appendedData,
            path: path,
            state: &workingState
        )
        let skippedPendingLines = try await importLiveTranscriptLines(
            parsed.lines, state: &workingState, fileReport: &fileReport
        )
        workingState.offset = nextOffset
        state = workingState
        return LiveImportResult(
            fileReport: fileReport,
            consumedLines: parsed.lines.count,
            skippedLines: parsed.skippedLines + skippedPendingLines,
            retainedPartialLine: !state.pendingFragment.isEmpty,
            metadataAvailable: state.metadata != nil,
            hasMoreData: !appendedData.isEmpty && nextOffset < fileSize
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
                workspaceID: context.workspaceID,
                surfaceID: context.surfaceID,
                fileReport: &fileReport
            )
        }
        state.context = context
        return fileReport
    }

    private func completedTranscriptLines(
        from appendedData: Data,
        path: String,
        state: inout LiveImportState
    ) -> (lines: [TranscriptLine], skippedLines: Int) {
        guard !appendedData.isEmpty else { return ([], 0) }
        var buffer = [UInt8](state.pendingFragment)
        var lines: [TranscriptLine] = []
        var skippedLines = 0
        for (index, byte) in appendedData.enumerated() {
            if byte == 0x0a {
                if state.discardingOversizedLine {
                    skippedLines += 1
                    state.discardingOversizedLine = false
                } else if !buffer.isEmpty {
                    if let text = String(bytes: buffer, encoding: .utf8) {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if let line = try? transcriptLine(
                                from: text, lineNumber: state.nextLineNumber, path: path
                            ) {
                                lines.append(line)
                            } else {
                                skippedLines += 1
                            }
                        }
                    } else {
                        skippedLines += 1
                    }
                }
                buffer.removeAll(keepingCapacity: true)
                state.nextLineNumber += 1
                state.lastCompletedLineOffset = state.offset + UInt64(index + 1)
            } else if !state.discardingOversizedLine {
                if buffer.count < Self.liveLineLimit {
                    buffer.append(byte)
                } else {
                    buffer.removeAll(keepingCapacity: false)
                    state.discardingOversizedLine = true
                }
            }
        }
        state.pendingFragment = Data(buffer)
        return (lines, skippedLines)
    }

    private func importLiveTranscriptLines(
        _ lines: [TranscriptLine],
        state: inout LiveImportState,
        fileReport: inout FileReport
    ) async throws -> Int {
        guard !lines.isEmpty else { return 0 }
        var skippedPendingLines = 0
        if state.metadata == nil {
            state.pendingLines.append(contentsOf: lines)
            if state.pendingLines.count > Self.livePendingLineLimit {
                skippedPendingLines = state.pendingLines.count - Self.livePendingLineLimit
                state.pendingLines.removeFirst(skippedPendingLines)
            }
            guard let metadata = sessionMetadata(from: state.pendingLines) else {
                return skippedPendingLines
            }
            state.metadata = metadata
            state.context = TranscriptContext(
                sessionID: metadata.sessionID,
                providerThreadID: metadata.providerThreadID,
                workspaceID: state.workspaceID,
                surfaceID: state.surfaceID,
                cwd: metadata.cwd,
                sessionStartedAt: metadata.timestamp,
                latestModel: metadata.model,
                latestEffort: metadata.effort
            )
        } else {
            state.pendingLines.append(contentsOf: lines)
        }

        guard let metadata = state.metadata,
              var context = state.context else { return skippedPendingLines }
        if let expectedSessionID = state.expectedSessionID,
           metadata.sessionID != expectedSessionID {
            throw LiveImportError.sessionMismatch
        }
        if !state.threadObserved {
            try await appendThread(
                metadata: metadata, line: metadata.line,
                workspaceID: context.workspaceID, surfaceID: context.surfaceID,
                fileReport: &fileReport
            )
            state.threadObserved = true
        }
        let importLines = state.pendingLines
        state.pendingLines = []
        for line in importLines {
            try await importLine(line, metadata: metadata, context: &context, fileReport: &fileReport)
        }
        state.context = context
        return skippedPendingLines
    }

    private enum LiveImportError: Error {
        case sessionMismatch
    }

}
