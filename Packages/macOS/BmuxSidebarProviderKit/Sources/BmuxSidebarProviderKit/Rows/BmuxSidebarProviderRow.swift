import Foundation

/// Row rendered inside a provider section.
public struct BmuxSidebarProviderRow: Identifiable, Codable, Equatable, Sendable {
    /// Stable row id.
    public var id: UUID
    /// Primary row title.
    public var title: String
    /// Workspace represented by the row.
    public var workspaceId: UUID
    /// Optional trailing accessory.
    public var accessory: BmuxSidebarProviderRowAccessory?
    /// Optional subtitle.
    public var subtitle: BmuxSidebarProviderText?
    /// Optional trailing text.
    public var trailingText: BmuxSidebarProviderText?
    /// Optional leading icon.
    public var leadingIcon: BmuxSidebarProviderIcon?

    /// Creates a provider row.
    public init(
        id: UUID,
        title: String,
        workspaceId: UUID,
        accessory: BmuxSidebarProviderRowAccessory?,
        subtitle: BmuxSidebarProviderText? = nil,
        trailingText: BmuxSidebarProviderText? = nil,
        leadingIcon: BmuxSidebarProviderIcon? = nil
    ) {
        self.id = id
        self.title = title
        self.workspaceId = workspaceId
        self.accessory = accessory
        self.subtitle = subtitle
        self.trailingText = trailingText
        self.leadingIcon = leadingIcon
    }
}
