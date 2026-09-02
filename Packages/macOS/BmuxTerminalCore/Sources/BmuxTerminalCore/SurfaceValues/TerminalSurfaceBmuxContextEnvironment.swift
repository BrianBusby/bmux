public import Foundation

/// The managed bmux context identity exported to a spawned terminal process.
///
/// These values become the `BMUX_WORKSPACE_ID` / `BMUX_SURFACE_ID` /
/// `BMUX_SOCKET_PATH` (and legacy tab/panel alias) environment variables.
public struct TerminalSurfaceBmuxContextEnvironment: Equatable, Sendable {
    /// The owning workspace id (exported as `BMUX_WORKSPACE_ID` / `BMUX_TAB_ID`).
    public let workspaceId: UUID

    /// The restart-stable workspace id used by durable provenance associations.
    public let stableWorkspaceId: UUID

    /// The surface id (exported as `BMUX_SURFACE_ID` / `BMUX_PANEL_ID`).
    public let surfaceId: UUID

    /// The control socket path (exported as `BMUX_SOCKET_PATH`).
    public let socketPath: String

    /// Creates the managed context identity.
    ///
    /// - Parameters:
    ///   - workspaceId: The owning workspace id.
    ///   - stableWorkspaceId: The restart-stable workspace id. Defaults to `workspaceId`.
    ///   - surfaceId: The surface id.
    ///   - socketPath: The control socket path.
    public init(workspaceId: UUID, stableWorkspaceId: UUID? = nil, surfaceId: UUID, socketPath: String) {
        self.workspaceId = workspaceId
        self.stableWorkspaceId = stableWorkspaceId ?? workspaceId
        self.surfaceId = surfaceId
        self.socketPath = socketPath
    }
}
