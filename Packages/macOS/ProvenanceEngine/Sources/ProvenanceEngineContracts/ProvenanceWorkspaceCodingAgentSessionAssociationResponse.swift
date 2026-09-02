import Foundation

/// Current-state response for one workspace coding-agent session association.
public struct ProvenanceWorkspaceCodingAgentSessionAssociationResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether a canonical association was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Stable client workspace identifier requested by the caller.
    public let workspaceID: String

    /// Agent kind requested by the caller.
    public let agentKind: String

    /// Canonical workspace-to-session association, when found.
    public let association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord?

    /// Factual diagnostic readiness for the association pipeline.
    public let readiness: ProvenanceWorkspaceCodingAgentSessionReadiness

    /// Creates a workspace coding-agent session association response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        workspaceID: String,
        agentKind: String,
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord?,
        readiness: ProvenanceWorkspaceCodingAgentSessionReadiness
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.workspaceID = workspaceID
        self.agentKind = agentKind
        self.association = association
        self.readiness = readiness
    }
}
