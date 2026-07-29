/// Whether the live execution telemetry projection is blocked on approval.
public struct ExecutionTelemetryLiveApprovalBlockedState: Sendable, Equatable, Codable {
    /// Whether at least one approval is pending.
    public let blocked: Bool

    /// Number of pending approvals in the sidecar projection.
    public let pendingCount: Int

    /// First pending approval id, when blocked.
    public let approvalID: String?

    /// First pending approval kind, when blocked.
    public let approvalKind: String?

    /// Provider operation id associated with the first pending approval.
    public let operationID: String?

    /// Bounded summary for the first pending approval.
    public let summary: String?

    /// Request timestamp, in Unix epoch milliseconds, for the first pending approval.
    public let requestedAtMs: Int?

    /// Creates an approval-blocked state.
    public init(
        blocked: Bool,
        pendingCount: Int,
        approvalID: String? = nil,
        approvalKind: String? = nil,
        operationID: String? = nil,
        summary: String? = nil,
        requestedAtMs: Int? = nil
    ) {
        self.blocked = blocked
        self.pendingCount = pendingCount
        self.approvalID = approvalID
        self.approvalKind = approvalKind
        self.operationID = operationID
        self.summary = summary
        self.requestedAtMs = requestedAtMs
    }

    private enum CodingKeys: String, CodingKey {
        case blocked
        case pendingCount
        case approvalID = "approvalId"
        case approvalKind
        case operationID = "operationId"
        case summary
        case requestedAtMs
    }
}
