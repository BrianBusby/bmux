import Foundation

/// Query parameters for resolving a workspace's canonical coding-agent session association.
public struct ProvenanceWorkspaceCodingAgentSessionAssociationRequest: Codable, Equatable, Sendable {
    /// Stable client workspace identifier to read.
    public let workspaceID: String

    /// Agent kind to resolve.
    public let agentKind: String

    /// Surface whose observed association must match, when resolving a caller.
    public let surfaceID: String?

    /// Provider session currently active in that surface, when resolving a caller.
    public let providerSessionID: String?

    /// Creates a workspace coding-agent session association request.
    ///
    /// Supply both caller identifiers to constrain the result to an observed association.
    /// Omit both to retain the workspace-level latest-session behavior.
    public init(workspaceID: String, agentKind: String = "codex", surfaceID: String? = nil, providerSessionID: String? = nil) {
        self.workspaceID = workspaceID
        self.agentKind = agentKind
        self.surfaceID = surfaceID
        self.providerSessionID = providerSessionID
    }
}
