import Foundation

/// Presentation command a provider can request from the BMUX sidebar host.
public enum BmuxSidebarProviderPresentationRequest: Codable, Equatable, Sendable {
    /// Open the workspace popover on a preferred tab.
    case openWorkspacePopover(workspaceId: UUID, preferredTab: BmuxSidebarProviderWorkspacePopoverTab)
    /// Open a detached workspace window on a preferred tab.
    case openWorkspaceWindow(workspaceId: UUID, preferredTab: BmuxSidebarProviderWorkspacePopoverTab)
    /// Ask BMUX to open a URL.
    case openURL(String)
}
