import Foundation

/// Current-state response for one workspace display projection.
public struct ProvenanceWorkspaceDisplayResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether a workspace display projection was found.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// Client workspace identifier requested by the caller.
    public let workspaceID: String

    /// Current workspace display projection, when found.
    public let display: ProvenanceWorkspaceDisplayRecord?

    /// Creates a workspace display current-state response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        workspaceID: String,
        display: ProvenanceWorkspaceDisplayRecord?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.workspaceID = workspaceID
        self.display = display
    }
}
