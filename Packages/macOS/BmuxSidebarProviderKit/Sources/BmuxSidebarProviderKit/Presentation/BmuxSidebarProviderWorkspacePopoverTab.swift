import Foundation

/// Tabs available when BMUX opens a workspace popover for a provider row.
public enum BmuxSidebarProviderWorkspacePopoverTab: String, Codable, CaseIterable, Equatable, Sendable {
    /// Notes tab.
    case notes
    /// Browser previews tab.
    case browser
    /// Pull request details tab.
    case pullRequest
}
