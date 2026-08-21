import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts

/// Records completed, structured coding-agent evidence from execution telemetry.
actor WorkProvenanceCodingAgentEvidenceRecorder {
    static let textLimit = 12_000
    static let summaryLimit = 4_000

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
            try await recordReasoningSummary(summary: summary, envelope: envelope, event: event)
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
        do {
            _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
            lastErrorDescription = nil
        } catch {
            if Self.isDuplicateAppendError(error) {
                lastErrorDescription = nil
                return
            }
            let description = String(describing: error)
            lastErrorDescription = description
            throw error
        }
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
        do {
            _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
            lastErrorDescription = nil
        } catch {
            if Self.isDuplicateAppendError(error) {
                lastErrorDescription = nil
                return
            }
            let description = String(describing: error)
            lastErrorDescription = description
            throw error
        }
    }
}
