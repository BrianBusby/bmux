import BmuxAgentChat
import Foundation

/// Reachability state observed while polling the Agent Chat sidecar for execution telemetry.
enum ExecutionTelemetryProjectionSidecarStatus: Equatable {
    case available(agentChatURL: URL)
    case unavailable(agentChatURL: URL, errorDescription: String)
}

struct ExecutionTelemetryWorkspaceAssociation: Equatable, Sendable {
    let workspaceID: String?
    let surfaceID: String?
    let workingDirectory: String?

    init(
        workspaceID: String? = nil,
        surfaceID: String? = nil,
        workingDirectory: String? = nil
    ) {
        self.workspaceID = workspaceID
        self.surfaceID = surfaceID
        self.workingDirectory = workingDirectory
    }
}

/// Projects selected live execution telemetry facts into durable provenance lifecycle evidence.
@MainActor
final class ExecutionTelemetryProvenanceProjectionService {
    let agentChatURL: URL

    private let sessionListClient: AgentChatSessionListClient
    private let liveProjectionClient: ExecutionTelemetryLiveProjectionClient
    private let eventClient: ExecutionTelemetryEventClient
    private let lifecycleRecorder: WorkProvenanceSessionLifecycleRecorder
    private let codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder?
    private let workspaceAssociationResolver: @MainActor (AgentChatSessionSummary) -> ExecutionTelemetryWorkspaceAssociation
    private let pollInterval: Duration
    private var sidecarStatusHandler: (ExecutionTelemetryProjectionSidecarStatus) -> Void
    private var projectionTask: Task<Void, Never>?
    private var recordedLifecycleKeys: Set<String> = []
    private var eventSequenceCursorBySessionID: [String: Int] = [:]
    private var lastEvidenceErrorDescriptionBySessionID: [String: String] = [:]

    /// Creates a durable lifecycle projection service.
    init(
        agentChatURL: URL,
        lifecycleRecorder: WorkProvenanceSessionLifecycleRecorder,
        codingAgentEvidenceRecorder: WorkProvenanceCodingAgentEvidenceRecorder? = nil,
        sessionListClient: AgentChatSessionListClient? = nil,
        liveProjectionClient: ExecutionTelemetryLiveProjectionClient? = nil,
        eventClient: ExecutionTelemetryEventClient? = nil,
        workspaceAssociationResolver: @escaping @MainActor (AgentChatSessionSummary) -> ExecutionTelemetryWorkspaceAssociation = {
            ExecutionTelemetryWorkspaceAssociation(workingDirectory: $0.cwd)
        },
        pollInterval: Duration = .seconds(5),
        sidecarStatusHandler: @escaping (ExecutionTelemetryProjectionSidecarStatus) -> Void = { _ in }
    ) {
        self.agentChatURL = agentChatURL
        self.lifecycleRecorder = lifecycleRecorder
        self.codingAgentEvidenceRecorder = codingAgentEvidenceRecorder
        self.sessionListClient = sessionListClient ?? AgentChatSessionListClient(baseURL: agentChatURL)
        self.liveProjectionClient = liveProjectionClient ?? ExecutionTelemetryLiveProjectionClient(baseURL: agentChatURL)
        self.eventClient = eventClient ?? ExecutionTelemetryEventClient(baseURL: agentChatURL)
        self.workspaceAssociationResolver = workspaceAssociationResolver
        self.pollInterval = pollInterval
        self.sidecarStatusHandler = sidecarStatusHandler
    }

    deinit {
        projectionTask?.cancel()
    }

    /// Starts polling the sidecar projection surface.
    func start() {
        guard projectionTask == nil else { return }
        projectionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.projectKnownSessions()
                do {
                    // Polling is the intended sidecar observation cadence; canceling the task ends the delay.
                    try await ContinuousClock().sleep(for: self?.pollInterval ?? .seconds(5))
                } catch {
                    return
                }
            }
        }
    }

    /// Stops polling the sidecar projection surface.
    func stop() {
        projectionTask?.cancel()
        projectionTask = nil
    }

    /// Updates the callback used for the current sidecar URL.
    func updateSidecarStatusHandler(
        _ sidecarStatusHandler: @escaping (ExecutionTelemetryProjectionSidecarStatus) -> Void
    ) {
        self.sidecarStatusHandler = sidecarStatusHandler
    }

    /// Projects currently known sidecar sessions once.
    func projectKnownSessions() async {
        let summaries: [AgentChatSessionSummary]
        do {
            summaries = try await sessionListClient.list()
        } catch {
            sidecarStatusHandler(
                .unavailable(
                    agentChatURL: agentChatURL,
                    errorDescription: String(describing: error)
                )
            )
            return
        }
        sidecarStatusHandler(.available(agentChatURL: agentChatURL))
        for summary in summaries {
            await project(summary: summary)
        }
    }

    private func project(summary: AgentChatSessionSummary) async {
        await projectLifecycle(summary: summary)
        await projectEvidenceEvents(summary: summary)
    }

    private func projectLifecycle(summary: AgentChatSessionSummary) async {
        let payload: ExecutionTelemetryLiveProjectionReadPayload
        do {
            payload = try await liveProjectionClient.read(sessionID: summary.id)
        } catch {
            return
        }
        guard let snapshot = payload.snapshot,
              snapshot.sessionID == summary.id,
              snapshot.lifecycleState == .idle || snapshot.lifecycleState == .running else {
            return
        }
        let key = lifecycleKey(
            sessionID: snapshot.sessionID,
            provider: snapshot.provider,
            providerSessionID: snapshot.providerSessionID
        )
        guard !recordedLifecycleKeys.contains(key) else { return }
        let workspaceAssociation = workspaceAssociationResolver(summary)
        await lifecycleRecorder.recordExecutionTelemetrySessionStarted(
            sessionID: snapshot.sessionID,
            provider: snapshot.provider,
            providerSessionID: snapshot.providerSessionID,
            workspaceID: workspaceAssociation.workspaceID,
            surfaceID: workspaceAssociation.surfaceID,
            workingDirectory: workspaceAssociation.workingDirectory ?? summary.cwd,
            timestamp: Self.timestamp(summary: summary, snapshot: snapshot)
        )
        recordedLifecycleKeys.insert(key)
    }

    private func projectEvidenceEvents(summary: AgentChatSessionSummary) async {
        guard let codingAgentEvidenceRecorder else { return }
        let cursor = eventSequenceCursorBySessionID[summary.id] ?? 0
        let payload: ExecutionTelemetryEventReadPayload
        do {
            payload = try await eventClient.read(sessionID: summary.id, afterSequence: cursor, limit: 200)
        } catch {
            return
        }
        guard payload.sessionID == summary.id else { return }
        let events = payload.events.sorted { lhs, rhs in lhs.sequence < rhs.sequence }
        for envelope in events where envelope.sequence > cursor {
            do {
                try await codingAgentEvidenceRecorder.record(summary: summary, envelope: envelope)
                eventSequenceCursorBySessionID[summary.id] = envelope.sequence
                lastEvidenceErrorDescriptionBySessionID[summary.id] = nil
            } catch {
                let description = String(describing: error)
                if lastEvidenceErrorDescriptionBySessionID[summary.id] != description {
                    NSLog("bmux provenance execution telemetry evidence recording failed: %@", description)
                }
                lastEvidenceErrorDescriptionBySessionID[summary.id] = description
                return
            }
        }
    }

    private func lifecycleKey(
        sessionID: String,
        provider: String,
        providerSessionID: String?
    ) -> String {
        [
            sessionID,
            provider.lowercased(),
            providerSessionID ?? "",
        ].joined(separator: "\u{1f}")
    }

    private static func timestamp(
        summary: AgentChatSessionSummary,
        snapshot: ExecutionTelemetryLiveProjectionSnapshot
    ) -> Date {
        let milliseconds = summary.createdAt > 0 ? summary.createdAt : Double(snapshot.latestActivityAtMs)
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }
}
