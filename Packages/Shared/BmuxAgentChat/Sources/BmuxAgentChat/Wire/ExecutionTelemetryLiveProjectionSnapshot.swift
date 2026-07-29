/// The bounded native-readable snapshot from the sidecar live execution projection.
public struct ExecutionTelemetryLiveProjectionSnapshot: Sendable, Equatable, Codable {
    /// bmux sidecar session id.
    public let sessionID: String

    /// Provider id for the session.
    public let provider: String

    /// Provider session id, when linked.
    public let providerSessionID: String?

    /// Current provider turn id, when a turn is running and the provider exposes one.
    public let currentProviderTurnID: String?

    /// Current projected lifecycle state.
    public let lifecycleState: ExecutionTelemetryLiveLifecycleState

    /// Number of active provider operations in the projection.
    public let activeOperationCount: Int

    /// Sidecar capture timestamp, in Unix epoch milliseconds, for the latest applied telemetry event.
    public let latestActivityAtMs: Int

    /// Latest bounded usage summary, when observed.
    public let latestUsageSummary: ExecutionTelemetryLiveUsageSummary?

    /// Latest bounded diagnostic summary, when observed.
    public let latestDiagnostic: ExecutionTelemetryLiveDiagnosticSummary?

    /// Current approval-blocked state.
    public let approvalBlocked: ExecutionTelemetryLiveApprovalBlockedState

    /// Bounded files-changed summary, when file changes have been observed.
    public let filesChanged: ExecutionTelemetryLiveFilesChangedSummary?

    /// Creates a live projection snapshot.
    public init(
        sessionID: String,
        provider: String,
        providerSessionID: String? = nil,
        currentProviderTurnID: String? = nil,
        lifecycleState: ExecutionTelemetryLiveLifecycleState,
        activeOperationCount: Int,
        latestActivityAtMs: Int,
        latestUsageSummary: ExecutionTelemetryLiveUsageSummary? = nil,
        latestDiagnostic: ExecutionTelemetryLiveDiagnosticSummary? = nil,
        approvalBlocked: ExecutionTelemetryLiveApprovalBlockedState,
        filesChanged: ExecutionTelemetryLiveFilesChangedSummary? = nil
    ) {
        self.sessionID = sessionID
        self.provider = provider
        self.providerSessionID = providerSessionID
        self.currentProviderTurnID = currentProviderTurnID
        self.lifecycleState = lifecycleState
        self.activeOperationCount = activeOperationCount
        self.latestActivityAtMs = latestActivityAtMs
        self.latestUsageSummary = latestUsageSummary
        self.latestDiagnostic = latestDiagnostic
        self.approvalBlocked = approvalBlocked
        self.filesChanged = filesChanged
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case provider
        case providerSessionID = "providerSessionId"
        case currentProviderTurnID = "currentProviderTurnId"
        case lifecycleState
        case activeOperationCount
        case latestActivityAtMs
        case latestUsageSummary
        case latestDiagnostic
        case approvalBlocked
        case filesChanged
    }
}
