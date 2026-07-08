import Foundation

/// Accessory control displayed at the trailing edge of a provider row.
public struct BmuxSidebarProviderRowAccessory: Codable, Equatable, Sendable {
    /// Accessory behavior.
    public var kind: BmuxSidebarProviderRowAccessoryKind
    /// SF Symbols name for the accessory icon.
    public var systemImageName: String
    /// Default popover tab when the accessory opens workspace details.
    public var defaultTab: BmuxSidebarProviderWorkspacePopoverTab

    /// Creates a row accessory.
    public init(
        kind: BmuxSidebarProviderRowAccessoryKind,
        systemImageName: String,
        defaultTab: BmuxSidebarProviderWorkspacePopoverTab
    ) {
        self.kind = kind
        self.systemImageName = systemImageName
        self.defaultTab = defaultTab
    }

    /// Standard workspace inspector accessory.
    public static let inspector = BmuxSidebarProviderRowAccessory(
        kind: .workspaceInspector,
        systemImageName: "ellipsis.circle",
        defaultTab: .notes
    )
}
