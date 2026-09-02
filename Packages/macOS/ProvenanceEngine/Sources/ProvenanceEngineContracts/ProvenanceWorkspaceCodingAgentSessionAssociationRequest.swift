import Foundation

/// Query parameters for resolving a workspace's canonical coding-agent session association.
public struct ProvenanceWorkspaceCodingAgentSessionAssociationRequest: Codable, Equatable, Sendable {
    /// Stable client workspace identifier to read.
    public let workspaceID: String

    /// Agent kind to resolve.
    public let agentKind: String

    /// Creates a workspace coding-agent session association request.
    public init(workspaceID: String, agentKind: String = "codex") {
        self.workspaceID = workspaceID
        self.agentKind = agentKind
    }
}
