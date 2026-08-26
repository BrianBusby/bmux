import Foundation
import ProvenanceEngineContracts

extension CLIProvenanceCodexTranscriptImporter {
    func appendCommand(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        item: [String: Any],
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        guard let command = Self.commandText(from: item) else { return }
        let completedAt = Self.dateFromMilliseconds(line.payload["completed_at_ms"])
            ?? Self.dateFromMilliseconds(item["completed_at_ms"])
            ?? line.timestamp
            ?? metadata.timestamp
        let startedAt = Self.dateFromMilliseconds(line.payload["started_at_ms"])
            ?? Self.dateFromMilliseconds(item["started_at_ms"])
        let cwd = Self.firstNonEmpty(Self.string(item["cwd"]), metadata.cwd)
        let gitContext = await gitContext(for: cwd, observedAt: completedAt)
        let exitCode = Self.int(item["exit_code"])
        let commandRecord = ProvenanceCodingAgentCommandRecord(
            id: recordID(prefix: "coding-agent-command", sessionID: metadata.sessionID, line: line, discriminator: Self.string(item["id"])),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            operationID: Self.string(item["id"]),
            command: Self.bounded(command, limit: Self.textLimit),
            cwd: cwd,
            status: Self.commandStatus(status: Self.string(item["status"]), exitCode: exitCode),
            exitCode: exitCode,
            outputSummary: nil,
            startedAt: startedAt,
            completedAt: completedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "command-\(Self.string(item["id"]) ?? "")"),
            eventType: .codingAgentCommandCompleted,
            timestamp: completedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentCommand: commandRecord
            )
        )
        try await append(event, stat: \.commands, fileReport: &fileReport)
    }

    func appendReasoningSummary(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        item: [String: Any],
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        guard let text = Self.reasoningText(from: item) else { return }
        try await appendReasoningSummary(
            metadata: metadata,
            line: line,
            itemID: Self.string(item["id"]),
            text: text,
            providerTurnID: providerTurnID,
            fileReport: &fileReport
        )
    }

    func appendReasoningSummary(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        itemID: String?,
        text: String,
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        guard let text = Self.trimmedNonEmpty(text).map({ Self.bounded($0, limit: Self.summaryLimit) }) else { return }
        let completedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: completedAt)
        let summary = ProvenanceCodingAgentReasoningSummaryRecord(
            id: recordID(prefix: "coding-agent-reasoning-summary", sessionID: metadata.sessionID, line: line, discriminator: itemID),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            itemID: Self.trimmedNonEmpty(itemID),
            text: text,
            completedAt: completedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "reasoning-\(itemID ?? "")"),
            eventType: .codingAgentReasoningSummaryCompleted,
            timestamp: completedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentReasoningSummary: summary
            )
        )
        try await append(event, stat: \.reasoningSummaries, fileReport: &fileReport)
    }

    func appendAssistantMessage(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        itemID: String?,
        text: String,
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        guard let text = Self.trimmedNonEmpty(text).map({ Self.bounded($0, limit: Self.textLimit) }) else { return }
        let completedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: completedAt)
        let message = ProvenanceCodingAgentAssistantMessageRecord(
            id: recordID(prefix: "coding-agent-assistant-message", sessionID: metadata.sessionID, line: line, discriminator: itemID),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            itemID: Self.trimmedNonEmpty(itemID),
            text: text,
            completedAt: completedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "assistant-message-\(itemID ?? "")"),
            eventType: .codingAgentAssistantMessageCompleted,
            timestamp: completedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentAssistantMessage: message
            )
        )
        try await append(event, stat: \.assistantMessages, fileReport: &fileReport)
    }

    func appendFileChangeAttribution(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        operationID: String?,
        changes: [PatchFileChange],
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let relativeChanges = changes.map { change in
            PatchFileChange(path: Self.repositoryRelativePath(change.path, gitContext: gitContext), status: change.status)
        }
        let diffFingerprint = stableIDFactory.id(
            prefix: "coding-agent-files",
            value: "\(metadata.sessionID)\n\(line.ordinal ?? line.lineNumber)\n\(relativeChanges.map { "\($0.status):\($0.path)" }.joined(separator: "\n"))"
        )
        let changeSetID = gitContext.map {
            stableIDFactory.changeSetID(worktreeID: $0.worktreeID, fingerprint: diffFingerprint)
        }
        let fileChangeRecords: [ProvenanceFileChangeRecord]
        if let gitContext, let changeSetID {
            fileChangeRecords = relativeChanges.map { change in
                ProvenanceFileChangeRecord(
                    id: stableIDFactory.fileChangeID(worktreeID: gitContext.worktreeID, path: change.path),
                    changeSetID: changeSetID,
                    repositoryID: gitContext.repositoryID,
                    worktreeID: gitContext.worktreeID,
                    path: change.path,
                    status: change.status,
                    attributionSource: .observed,
                    attributionConfidence: .medium,
                    updatedAt: observedAt
                )
            }
        } else {
            fileChangeRecords = []
        }
        let attribution = ProvenanceCodingAgentFileChangeAttributionRecord(
            id: recordID(prefix: "coding-agent-file-change", sessionID: metadata.sessionID, line: line, discriminator: operationID),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            operationID: Self.trimmedNonEmpty(operationID),
            changeSetID: changeSetID,
            fileChangeIDs: fileChangeRecords.map(\.id),
            paths: relativeChanges.map(\.path),
            summary: nil,
            observedAt: observedAt,
            source: .observed,
            confidence: .medium
        )
        let changeSet = gitContext.flatMap { context -> ProvenanceChangeSetRecord? in
            guard let changeSetID else { return nil }
            return ProvenanceChangeSetRecord(
                id: changeSetID,
                worktreeID: context.worktreeID,
                summary: "Coding-agent transcript file changes",
                diffFingerprint: diffFingerprint,
                createdAt: observedAt
            )
        }
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "files-\(operationID ?? "")"),
            eventType: .codingAgentFileChangeAttributed,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .medium,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                changeSet: changeSet,
                fileChanges: fileChangeRecords,
                codingAgentFileChangeAttribution: attribution
            )
        )
        try await append(event, stat: \.fileChanges, fileReport: &fileReport)
    }

    func append(
        _ event: ProvenanceEngineContracts.ProvenanceEvent,
        stat: WritableKeyPath<FileReport, Int>,
        fileReport: inout FileReport
    ) async throws {
        do {
            _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
            fileReport.eventsAppended += 1
            fileReport[keyPath: stat] += 1
        } catch {
            if Self.isDuplicateAppendError(error) {
                fileReport.duplicateEvents += 1
                return
            }
            throw error
        }
    }

    func provenanceEvent(
        id: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        sessionID: String,
        gitContext: GitContext?,
        confidence: ProvenanceConfidence,
        payload: ProvenanceEventPayload
    ) -> ProvenanceEngineContracts.ProvenanceEvent {
        ProvenanceEngineContracts.ProvenanceEvent(
            id: id,
            eventType: eventType,
            timestamp: timestamp,
            repositoryID: gitContext?.repositoryID,
            worktreeID: gitContext?.worktreeID,
            sessionID: sessionID,
            source: .observed,
            evidenceOrigin: Self.transcriptOrigin,
            evidenceScope: Self.localEvidenceScope,
            confidence: confidence,
            payload: payload
        )
    }
}
