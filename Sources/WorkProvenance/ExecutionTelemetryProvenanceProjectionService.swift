import BmuxAgentChat
import Foundation

/// Projects selected live execution telemetry facts into durable provenance lifecycle evidence.
@MainActor
final class ExecutionTelemetryProvenanceProjectionService {
    let agentChatURL: URL

    private let sessionListClient: AgentChatSessionListClient
    private let liveProjectionClient: ExecutionTelemetryLiveProjectionClient
    private let lifecycleRecorder: WorkProvenanceSessionLifecycleRecorder
    private let pollInterval: Duration
    private var projectionTask: Task<Void, Never>?
    private var recordedLifecycleKeys: Set<String> = []

    /// Creates a durable lifecycle projection service.
    init(
        agentChatURL: URL,
        lifecycleRecorder: WorkProvenanceSessionLifecycleRecorder,
        sessionListClient: AgentChatSessionListClient? = nil,
        liveProjectionClient: ExecutionTelemetryLiveProjectionClient? = nil,
        pollInterval: Duration = .seconds(5)
    ) {
        self.agentChatURL = agentChatURL
        self.lifecycleRecorder = lifecycleRecorder
        self.sessionListClient = sessionListClient ?? AgentChatSessionListClient(baseURL: agentChatURL)
        self.liveProjectionClient = liveProjectionClient ?? ExecutionTelemetryLiveProjectionClient(baseURL: agentChatURL)
        self.pollInterval = pollInterval
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

    /// Projects currently known sidecar sessions once.
    func projectKnownSessions() async {
        let summaries: [AgentChatSessionSummary]
        do {
            summaries = try await sessionListClient.list()
        } catch {
            return
        }
        for summary in summaries {
            await project(summary: summary)
        }
    }

    private func project(summary: AgentChatSessionSummary) async {
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
        await lifecycleRecorder.recordExecutionTelemetrySessionStarted(
            sessionID: snapshot.sessionID,
            provider: snapshot.provider,
            providerSessionID: snapshot.providerSessionID,
            workingDirectory: summary.cwd,
            timestamp: Self.timestamp(summary: summary, snapshot: snapshot)
        )
        recordedLifecycleKeys.insert(key)
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
