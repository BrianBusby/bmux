public import Foundation

/// Minimal identity retained for one logical workspace close.
public struct WorkspaceExplorerCloseRecord: Sendable {
    /// Stable identity shared by all closes and restores of the workspace.
    public let stableID: UUID
    /// Display title captured when the workspace closed.
    public let title: String
    /// Time the workspace closed.
    public let closedAt: Date
    /// Optional workspace identity color captured at close.
    public let colorHex: String?

    /// Creates the identity stored by the close journal.
    /// - Parameters:
    ///   - stableID: Stable logical workspace identifier.
    ///   - title: Last display title.
    ///   - closedAt: Time of close.
    ///   - colorHex: Optional identity color.
    public init(stableID: UUID, title: String, closedAt: Date, colorHex: String?) {
        self.stableID = stableID
        self.title = title
        self.closedAt = closedAt
        self.colorHex = colorHex
    }
}
