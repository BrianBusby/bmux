import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts

/// Records completed, structured coding-agent evidence from execution telemetry.
actor WorkProvenanceCodingAgentEvidenceRecorder {
    static let textLimit = 12_000
    static let summaryLimit = 4_000
    private static let appendRetryDeadlineSeconds: TimeInterval = 120
    private static let appendRetryInitialDelayNanoseconds: UInt64 = 250_000_000
    private static let appendRetryMaximumDelayNanoseconds: UInt64 = 2_000_000_000

    let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    let gitInspector: any WorkProvenanceGitInspecting
    let stableIDFactory: WorkProvenanceStableIDFactory

    var providerThreadIDBySessionID: [String: String] = [:]
    var currentProviderTurnIDBySessionID: [String: String] = [:]
    var pendingPromptBySessionID: [String: PendingPrompt] = [:]
    var pendingToolByKey: [String: PendingTool] = [:]

    /// Last persistence error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates a recorder backed by the public Provenance Engine write API.
    init(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: any WorkProvenanceGitInspecting = WorkProvenanceGitInspector(),
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory()
    ) {
        self.client = client
        self.gitInspector = gitInspector
        self.stableIDFactory = stableIDFactory
    }

    /// Records one canonical sidecar telemetry envelope when it contains durable evidence.
    func record(
        summary: AgentChatSessionSummary,
        envelope: ExecutionTelemetryEventEnvelope
    ) async throws {
        guard normalizedProvider(summary.provider) == "codex",
              normalizedProvider(envelope.provider) == "codex",
              envelope.sessionID == summary.id else {
            return
        }

        switch envelope.event {
        case .sessionStarted:
            return
        case .providerSessionLinked(let event):
            try await recordThread(summary: summary, envelope: envelope, providerThreadID: event.providerSessionID)
        case .promptSubmitted(let event):
            try await recordPromptOrDefer(summary: summary, envelope: envelope, text: event.text)
        case .turnStarted(let event):
            try await recordTurnStarted(summary: summary, envelope: envelope, event: event)
        case .turnCompleted(let event):
            try await recordTurnFinished(summary: summary, envelope: envelope, event: event, status: "completed")
        case .turnFailed(let event):
            try await recordTurnFinished(summary: summary, envelope: envelope, event: event, status: "failed")
        case .planUpdated(let event):
            try await recordPlanUpdate(summary: summary, envelope: envelope, event: event)
        case .messageCompleted(let event):
            try await recordCompletedMessage(summary: summary, envelope: envelope, event: event)
        case .toolStarted(let event):
            recordPendingTool(summary: summary, envelope: envelope, event: event)
        case .toolCompleted(let event):
            try await recordCompletedTool(summary: summary, envelope: envelope, event: event)
        case .filesChanged(let event):
            try await recordFilesChanged(summary: summary, envelope: envelope, event: event)
        case .unsupported:
            return
        }
    }

    func append(
        eventType: ProvenanceEventType,
        envelope: ExecutionTelemetryEventEnvelope,
        timestamp: Date,
        sessionID: String,
        repositoryID: String?,
        worktreeID: String?,
        confidence: ProvenanceConfidence,
        payload: ProvenanceEventPayload
    ) async throws {
        let event = ProvenanceEngineContracts.ProvenanceEvent(
            id: "event-\(envelope.eventID)",
            eventType: eventType,
            timestamp: timestamp,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            sessionID: sessionID,
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: confidence,
            payload: payload
        )
        try await appendEventHandlingTransientContention(event)
    }

    func append(
        eventType: ProvenanceEventType,
        envelopeID: String,
        timestamp: Date,
        sessionID: String,
        repositoryID: String?,
        worktreeID: String?,
        confidence: ProvenanceConfidence,
        payload: ProvenanceEventPayload
    ) async throws {
        let event = ProvenanceEngineContracts.ProvenanceEvent(
            id: "event-\(envelopeID)",
            eventType: eventType,
            timestamp: timestamp,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            sessionID: sessionID,
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: confidence,
            payload: payload
        )
        try await appendEventHandlingTransientContention(event)
    }

    private func appendEventHandlingTransientContention(
        _ event: ProvenanceEngineContracts.ProvenanceEvent
    ) async throws {
        let deadline = Date().addingTimeInterval(Self.appendRetryDeadlineSeconds)
        var delayNanoseconds = Self.appendRetryInitialDelayNanoseconds
        var attempt = 0
        while true {
            do {
                _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
                lastErrorDescription = nil
                return
            } catch {
                if Self.isDuplicateAppendError(error) {
                    lastErrorDescription = nil
                    return
                }
                guard Self.isTransientSQLiteContention(error), Date() < deadline else {
                    let description = String(describing: error)
                    lastErrorDescription = description
                    throw error
                }
                attempt += 1
                #if DEBUG
                if attempt == 1 || attempt % 10 == 0 {
                    bmuxDebugLog(
                        "workProvenance.codexEvidence.append.retry event=\(event.id) "
                            + "attempt=\(attempt) error=\(String(describing: error))"
                    )
                }
                #endif
                try Task.checkCancellation()
                // Backoff is the intended retry delay for transient SQLite writer contention.
                try await Task.sleep(nanoseconds: delayNanoseconds)
                delayNanoseconds = min(
                    delayNanoseconds * 2,
                    Self.appendRetryMaximumDelayNanoseconds
                )
            }
        }
    }

    private static func isTransientSQLiteContention(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("database is locked")
            || description.contains("database table is locked")
            || description.contains("sqlite_busy")
            || description.contains("sqlite_locked")
    }
}
