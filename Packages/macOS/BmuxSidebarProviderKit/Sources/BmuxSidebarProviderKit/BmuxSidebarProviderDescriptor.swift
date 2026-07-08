import Foundation

/// Stable metadata BMUX uses to identify and present an in-process sidebar provider.
public struct BmuxSidebarProviderDescriptor: Identifiable, Codable, Equatable, Sendable {
    /// Provider id for the built-in workspace sidebar.
    public static let defaultWorkspacesID = "bmux.sidebar.default"

    /// Stable provider identifier persisted in user selection state.
    public var id: String
    /// Localized provider title shown in sidebar provider menus.
    public var title: BmuxSidebarProviderLocalizedText
    /// Optional localized detail text shown under the provider title.
    public var subtitle: BmuxSidebarProviderLocalizedText?
    /// SF Symbols name used for this provider in menus.
    public var systemImageName: String
    /// Whether the provider is supplied by BMUX rather than a package example.
    public var isHostProvided: Bool

    /// Creates sidebar provider metadata.
    public init(
        id: String,
        title: BmuxSidebarProviderLocalizedText,
        subtitle: BmuxSidebarProviderLocalizedText? = nil,
        systemImageName: String,
        isHostProvided: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImageName = systemImageName
        self.isHostProvided = isHostProvided
    }

    /// Descriptor for BMUX's built-in workspace sidebar.
    public static let defaultWorkspaces = BmuxSidebarProviderDescriptor(
        id: defaultWorkspacesID,
        title: BmuxSidebarProviderLocalizedText(key: "sidebar.provider.default.title", defaultValue: "Default Workspaces"),
        subtitle: BmuxSidebarProviderLocalizedText(key: "sidebar.provider.default.subtitle", defaultValue: "bmux"),
        systemImageName: "list.bullet",
        isHostProvided: true
    )
}
