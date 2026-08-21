import CryptoKit
import Foundation
import ProvenanceEngineContracts

struct CLIProvenanceCodexTranscriptImporter {
    static let defaultTranscriptPath = "~/.codex/sessions"

    private static let textLimit = 12_000
    private static let summaryLimit = 4_000
    private static let transcriptOrigin = ProvenanceEvidenceOrigin(rawValue: "codex-transcript")
    private static let localEvidenceScope = ProvenanceEvidenceScope(level: .personal, id: "bmux-local")

    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    private let stableIDFactory = StableIDFactory()

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

    private func appendThread(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let session = ProvenanceSessionRecord(
            id: metadata.sessionID,
            agentKind: "codex",
            worktreeID: gitContext?.worktreeID,
            cwd: metadata.cwd,
            status: "active",
            startedAt: metadata.timestamp,
            updatedAt: observedAt
        )
        let thread = ProvenanceCodingAgentThreadRecord(
            id: threadRecordID(providerThreadID: metadata.providerThreadID),
            sessionID: metadata.sessionID,
            provider: "codex",
            providerThreadID: metadata.providerThreadID,
            worktreeID: gitContext?.worktreeID,
            source: .observed,
            confidence: .high,
            firstObservedAt: observedAt,
            updatedAt: observedAt
        )
        let identities = [
            externalIdentity(
                sessionID: metadata.sessionID,
                kind: "provider_session",
                externalID: metadata.providerThreadID,
                observedAt: observedAt
            ),
            externalIdentity(
                sessionID: metadata.sessionID,
                kind: "thread",
                externalID: metadata.providerThreadID,
                observedAt: observedAt
            )
        ]
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "thread"),
            eventType: .codingAgentThreadObserved,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                session: session,
                externalIdentities: identities,
                codingAgentThread: thread
            )
        )
        try await append(event, stat: \.threads, fileReport: &fileReport)
    }

    private func ensureTurnObserved(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        context: inout TranscriptContext,
        providerTurnID: String,
        fileReport: inout FileReport
    ) async throws {
        guard !context.observedProviderTurnIDs.contains(providerTurnID) else { return }
        try await appendTurn(
            metadata: metadata,
            line: line,
            providerTurnID: providerTurnID,
            status: "observed",
            model: context.latestModel,
            startedAt: nil,
            completedAt: nil,
            fileReport: &fileReport
        )
        context.observedProviderTurnIDs.insert(providerTurnID)
    }

    private func appendTurn(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        providerTurnID: String,
        status: String,
        model: String?,
        startedAt: Date?,
        completedAt: Date?,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = completedAt ?? startedAt ?? line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let identity = externalIdentity(
            sessionID: metadata.sessionID,
            kind: "turn",
            externalID: providerTurnID,
            observedAt: observedAt
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: turnRecordID(providerTurnID: providerTurnID),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            provider: "codex",
            providerTurnID: providerTurnID,
            status: status,
            model: Self.trimmedNonEmpty(model),
            effort: nil,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "turn-\(providerTurnID)-\(status)"),
            eventType: .codingAgentTurnObserved,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                externalIdentities: [identity],
                codingAgentTurn: turn
            )
        )
        try await append(event, stat: \.turns, fileReport: &fileReport)
    }

    private func appendPrompt(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        text: String,
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        guard let text = Self.trimmedNonEmpty(text).map({ Self.bounded($0, limit: Self.textLimit) }) else { return }
        let observedAt = line.timestamp ?? metadata.timestamp
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: recordID(prefix: "coding-agent-prompt", sessionID: metadata.sessionID, line: line, discriminator: text),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            text: text,
            submittedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "prompt"),
            eventType: .codingAgentPromptSubmitted,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentPrompt: prompt
            )
        )
        try await append(event, stat: \.prompts, fileReport: &fileReport)
    }

    private func appendPlan(
        metadata: TranscriptMetadata,
        line: TranscriptLine,
        plan: PlanUpdate,
        providerTurnID: String?,
        fileReport: inout FileReport
    ) async throws {
        let observedAt = line.timestamp ?? metadata.timestamp
        let steps = plan.steps.enumerated().map { index, step in
            ProvenanceCodingAgentPlanStepRecord(
                id: recordID(
                    prefix: "coding-agent-plan-step",
                    sessionID: metadata.sessionID,
                    line: line,
                    discriminator: "\(index)\n\(step.text)\n\(step.status)"
                ),
                order: index,
                text: Self.bounded(step.text, limit: Self.summaryLimit),
                status: Self.bounded(step.status, limit: 160)
            )
        }
        let update = ProvenanceCodingAgentPlanUpdateRecord(
            id: recordID(prefix: "coding-agent-plan", sessionID: metadata.sessionID, line: line),
            sessionID: metadata.sessionID,
            threadID: threadRecordID(providerThreadID: metadata.providerThreadID),
            turnID: providerTurnID.map(turnRecordID(providerTurnID:)),
            provider: "codex",
            explanation: plan.explanation.map { Self.bounded($0, limit: Self.summaryLimit) },
            steps: steps,
            observedAt: observedAt,
            source: .observed,
            confidence: .high
        )
        let gitContext = await gitContext(for: metadata.cwd, observedAt: observedAt)
        let event = provenanceEvent(
            id: eventID(sessionID: metadata.sessionID, line: line, kind: "plan"),
            eventType: .codingAgentPlanUpdated,
            timestamp: observedAt,
            sessionID: metadata.sessionID,
            gitContext: gitContext,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: gitContext?.repository,
                worktree: gitContext?.worktree,
                codingAgentPlanUpdate: update
            )
        )
        try await append(event, stat: \.plans, fileReport: &fileReport)
    }

    private func appendCommand(
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

    private func appendReasoningSummary(
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

    private func appendReasoningSummary(
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

    private func appendFileChangeAttribution(
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

    private func append(
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

    private func provenanceEvent(
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

    private func gitContext(for directory: String?, observedAt: Date) async -> GitContext? {
        guard let directory = Self.trimmedNonEmpty(directory),
              let snapshot = Self.gitSnapshot(for: directory) else {
            return nil
        }
        let repositoryID = stableIDFactory.repositoryID(repositoryRoot: snapshot.repositoryRoot)
        let worktreeID = stableIDFactory.worktreeID(repositoryRoot: snapshot.repositoryRoot)
        return GitContext(
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            repository: ProvenanceRepositoryRecord(
                id: repositoryID,
                path: snapshot.repositoryRoot,
                commonDirectory: snapshot.commonDirectory,
                remoteSlug: snapshot.remoteSlug,
                createdAt: observedAt,
                updatedAt: observedAt
            ),
            worktree: ProvenanceWorktreeRecord(
                id: worktreeID,
                repositoryID: repositoryID,
                path: snapshot.repositoryRoot,
                branch: snapshot.branch,
                currentHEAD: snapshot.headCommit,
                isDirty: snapshot.isDirty,
                status: "active",
                lastReconciledAt: observedAt,
                updatedAt: observedAt
            )
        )
    }

    private static func gitSnapshot(for directory: String) -> GitSnapshot? {
        guard let root = gitText(["-C", directory, "rev-parse", "--show-toplevel"]) else {
            return nil
        }
        let commonDirectory = gitText(["-C", root, "rev-parse", "--git-common-dir"]).map {
            absolutePath($0, relativeTo: root)
        }
        let branch = gitText(["-C", root, "branch", "--show-current"])
        let headCommit = gitText(["-C", root, "rev-parse", "--verify", "HEAD"])
        let status = gitText(["-C", root, "status", "--porcelain=v1", "--untracked-files=all"])
        let remoteSlug = gitText(["-C", root, "config", "--get", "remote.origin.url"]).flatMap(remoteSlug)
        return GitSnapshot(
            repositoryRoot: root,
            commonDirectory: commonDirectory,
            remoteSlug: remoteSlug,
            branch: branch,
            headCommit: headCommit,
            isDirty: status?.isEmpty == false
        )
    }

    private static func gitText(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: outputData, encoding: .utf8) else {
            return nil
        }
        return trimmedNonEmpty(text)
    }

    private static func absolutePath(_ path: String, relativeTo root: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        return URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(path)
            .standardizedFileURL
            .path
    }

    private static func remoteSlug(_ remoteURL: String) -> String? {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withoutSuffix = trimmed.hasSuffix(".git") ? String(trimmed.dropLast(4)) : trimmed
        if let range = withoutSuffix.range(of: "github.com[:/]", options: .regularExpression) {
            return String(withoutSuffix[range.upperBound...])
        }
        return nil
    }

    private func threadRecordID(providerThreadID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-thread", value: "codex\n\(providerThreadID)")
    }

    private func turnRecordID(providerTurnID: String) -> String {
        stableIDFactory.id(prefix: "coding-agent-turn", value: "codex\n\(providerTurnID)")
    }

    private func externalIdentity(
        sessionID: String,
        kind: String,
        externalID: String,
        observedAt: Date
    ) -> ProvenanceExternalIdentityRecord {
        ProvenanceExternalIdentityRecord(
            id: stableIDFactory.id(prefix: "identity", value: "\(sessionID)\ncodex\n\(kind)\n\(externalID)"),
            sessionID: sessionID,
            system: "codex",
            kind: kind,
            externalID: externalID,
            source: .observed,
            confidence: .high,
            createdAt: observedAt,
            updatedAt: observedAt
        )
    }

    private func eventID(sessionID: String, line: TranscriptLine, kind: String) -> String {
        stableIDFactory.id(
            prefix: "event",
            value: "codex-transcript\n\(sessionID)\n\(line.ordinal ?? line.lineNumber)\n\(kind)"
        )
    }

    private func recordID(
        prefix: String,
        sessionID: String,
        line: TranscriptLine,
        discriminator: String? = nil
    ) -> String {
        stableIDFactory.id(
            prefix: prefix,
            value: "codex-transcript\n\(sessionID)\n\(line.ordinal ?? line.lineNumber)\n\(discriminator ?? "")"
        )
    }

    private func transcriptLines(at url: URL) throws -> [TranscriptLine] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.error.invalidUTF8",
                    defaultValue: "Codex transcript is not valid UTF-8: %@"
                ),
                url.path
            ))
        }
        return try text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { index, lineText -> TranscriptLine? in
                let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let data = Data(trimmed.utf8)
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let payload = Self.dictionary(object["payload"]) else {
                    throw ImportError(message: String.localizedStringWithFormat(
                        String(
                            localized: "cli.provenance.import.error.invalidJSONLine",
                            defaultValue: "Codex transcript line is not a JSON object: %@:%d"
                        ),
                        url.path,
                        index + 1
                    ))
                }
                return TranscriptLine(
                    lineNumber: index + 1,
                    ordinal: Self.int(object["ordinal"]),
                    type: Self.string(object["type"]) ?? "",
                    timestamp: Self.dateFromString(Self.string(object["timestamp"])),
                    payload: payload
                )
            }
    }

    private func sessionMetadata(from lines: [TranscriptLine]) -> TranscriptMetadata? {
        for line in lines where line.type == "session_meta" {
            guard let sessionID = Self.trimmedNonEmpty(Self.firstNonEmpty(
                Self.string(line.payload["session_id"]),
                Self.string(line.payload["id"])
            )) else {
                continue
            }
            return TranscriptMetadata(
                line: line,
                sessionID: sessionID,
                providerThreadID: sessionID,
                cwd: Self.trimmedNonEmpty(Self.string(line.payload["cwd"])),
                timestamp: Self.dateFromString(Self.string(line.payload["timestamp"])) ?? line.timestamp ?? Date(timeIntervalSince1970: 0),
                model: Self.trimmedNonEmpty(Self.string(line.payload["model"]))
                    ?? Self.trimmedNonEmpty(Self.string(line.payload["model_provider"]))
            )
        }
        return nil
    }

    private static func planUpdate(from payload: [String: Any]) -> PlanUpdate? {
        guard let arguments = parsedArguments(from: payload["arguments"]) ?? dictionary(payload["parsed_arguments"]) else {
            return nil
        }
        let rawSteps = arrayOfDictionaries(arguments["plan"]) ?? arrayOfDictionaries(arguments["steps"]) ?? []
        let steps = rawSteps.compactMap { item -> PlanStep? in
            guard let text = trimmedNonEmpty(firstNonEmpty(string(item["step"]), string(item["text"]))) else {
                return nil
            }
            return PlanStep(text: text, status: trimmedNonEmpty(string(item["status"])) ?? "unknown")
        }
        guard !steps.isEmpty else { return nil }
        return PlanUpdate(explanation: trimmedNonEmpty(string(arguments["explanation"])), steps: steps)
    }

    private static func messageText(from payload: [String: Any]) -> String? {
        if let text = trimmedNonEmpty(string(payload["text"])) {
            return text
        }
        return textFragments(from: payload["content"]).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func reasoningText(from payload: [String: Any]) -> String? {
        if let text = trimmedNonEmpty(string(payload["text"])) {
            return text
        }
        if let text = trimmedNonEmpty(string(payload["summary_text"])) {
            return text
        }
        let summaryText = textFragments(from: payload["summary_text"]).joined(separator: "\n")
        if let text = trimmedNonEmpty(summaryText) {
            return text
        }
        let summary = textFragments(from: payload["summary"]).joined(separator: "\n")
        return trimmedNonEmpty(summary)
    }

    private static func textFragments(from value: Any?) -> [String] {
        if let text = trimmedNonEmpty(string(value)) {
            return [text]
        }
        if let array = value as? [Any] {
            return array.flatMap(textFragments(from:))
        }
        if let dictionary = dictionary(value) {
            return [
                string(dictionary["text"]),
                string(dictionary["content"]),
                string(dictionary["summary_text"])
            ]
            .compactMap(trimmedNonEmpty)
            + textFragments(from: dictionary["summary"])
        }
        return []
    }

    private static func commandText(from item: [String: Any]) -> String? {
        if let argv = item["command"] as? [String], !argv.isEmpty {
            return argv.map(shellQuote).joined(separator: " ")
        }
        if let argv = item["command"] as? [Any] {
            let values = argv.compactMap(string)
            if !values.isEmpty {
                return values.map(shellQuote).joined(separator: " ")
            }
        }
        return trimmedNonEmpty(string(item["command"]))
    }

    private static func shellQuote(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func commandStatus(status: String?, exitCode: Int?) -> String {
        guard let status = trimmedNonEmpty(status)?.lowercased() else {
            return exitCode.map { $0 == 0 ? "succeeded" : "failed" } ?? "unknown"
        }
        if status == "completed" {
            return exitCode.map { $0 == 0 ? "succeeded" : "failed" } ?? "completed"
        }
        return status
    }

    private static func patchFileChanges(from patch: String) -> [PatchFileChange] {
        var changes: [PatchFileChange] = []
        for line in patch.components(separatedBy: .newlines) {
            if let path = patchPath(line, marker: "*** Add File:") {
                changes.append(PatchFileChange(path: path, status: "added"))
            } else if let path = patchPath(line, marker: "*** Delete File:") {
                changes.append(PatchFileChange(path: path, status: "deleted"))
            } else if let path = patchPath(line, marker: "*** Update File:") {
                changes.append(PatchFileChange(path: path, status: "modified"))
            } else if let path = patchPath(line, marker: "*** Move to:") {
                changes.append(PatchFileChange(path: path, status: "renamed"))
            }
        }
        var seen: Set<String> = []
        return changes.filter { change in
            let key = "\(change.status)\n\(change.path)"
            return seen.insert(key).inserted
        }
    }

    private static func patchPath(_ line: String, marker: String) -> String? {
        guard line.hasPrefix(marker) else { return nil }
        return trimmedNonEmpty(String(line.dropFirst(marker.count)))
    }

    private static func repositoryRelativePath(_ path: String, gitContext: GitContext?) -> String {
        guard path.hasPrefix("/"),
              let root = gitContext?.worktree.path else {
            return path
        }
        let normalizedRoot = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL.path
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let prefix = normalizedRoot.hasSuffix("/") ? normalizedRoot : "\(normalizedRoot)/"
        guard normalizedPath.hasPrefix(prefix) else { return normalizedPath }
        return String(normalizedPath.dropFirst(prefix.count))
    }

    private static func parsedArguments(from value: Any?) -> [String: Any]? {
        if let dictionary = dictionary(value) {
            return dictionary
        }
        guard let text = trimmedNonEmpty(string(value)),
              let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func turnID(from payload: [String: Any]) -> String? {
        let metadata = dictionary(payload["internal_chat_message_metadata_passthrough"])
        return firstNonEmpty(
            string(payload["turn_id"]),
            string(metadata?["turn_id"])
        )
    }

    private static func dateFromMilliseconds(_ value: Any?) -> Date? {
        double(value).map { Date(timeIntervalSince1970: $0 / 1_000) }
    }

    private static func dateFromSeconds(_ value: Any?) -> Date? {
        double(value).map { Date(timeIntervalSince1970: $0) }
    }

    private static func dateFromString(_ value: String?) -> Date? {
        guard let value = trimmedNonEmpty(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func isDuplicateAppendError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("provenance_events")
            && (description.contains("unique") || description.contains("constraint") || description.contains("duplicate"))
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func arrayOfDictionaries(_ value: Any?) -> [[String: Any]]? {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries
        }
        return (value as? [Any])?.compactMap(dictionary)
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = string(value) { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = string(value) { return Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value = trimmedNonEmpty(value) {
                return value
            }
        }
        return nil
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }
}

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
        var fileChanges: Int = 0
    }
}

private extension CLIProvenanceCodexTranscriptImporter {
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
    }

    struct TranscriptContext {
        let sessionID: String
        let providerThreadID: String
        var cwd: String?
        let sessionStartedAt: Date
        var latestModel: String?
        var currentProviderTurnID: String?
        var observedProviderTurnIDs: Set<String> = []
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
