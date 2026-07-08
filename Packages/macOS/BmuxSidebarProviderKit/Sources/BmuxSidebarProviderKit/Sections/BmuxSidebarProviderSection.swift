import Foundation

/// Rendered section with tree metadata and concrete rows.
public struct BmuxSidebarProviderSection: Identifiable, Codable, Equatable, Sendable {
    /// Stable section id.
    public var id: String
    /// Tree/list section metadata.
    public var treeSection: BmuxSidebarProviderTreeSection
    /// Rows rendered in this section.
    public var rows: [BmuxSidebarProviderRow]

    /// Creates a provider section.
    public init(
        id: String,
        treeSection: BmuxSidebarProviderTreeSection,
        rows: [BmuxSidebarProviderRow]
    ) {
        self.id = id
        self.treeSection = treeSection
        self.rows = rows
    }
}
