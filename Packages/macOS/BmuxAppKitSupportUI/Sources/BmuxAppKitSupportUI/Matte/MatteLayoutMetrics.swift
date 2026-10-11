public import SwiftUI

/// Shared shape, spacing, and hit-target metrics for matte chrome.
public struct MatteLayoutMetrics: Sendable {
    /// Workspace card corner radius in points.
    public let cardRadius: Double

    /// Main panel corner radius in points.
    public let panelRadius: Double

    /// Terminal inset corner radius in points.
    public let terminalRadius: Double

    /// Regular control corner radius in points.
    public let controlRadius: Double

    /// Compact control corner radius in points.
    public let compactControlRadius: Double

    /// Regular control height in points.
    public let controlHeight: Double

    /// Compact control height in points.
    public let compactControlHeight: Double

    /// Side, bottom, and sidebar-to-panel gutter in points.
    public let windowGutter: Double

    /// Header inset measured from the reference wordmark's leading ink edge.
    public let brandHeaderHorizontalInset: Double

    /// Visual header baseline offset, preserving the sidebar's existing layout position.
    public let brandHeaderVerticalOffset: Double

    /// Preserved native brand-group spacing; the reference does not specify this gap.
    public let brandHeaderContentGap: Double

    /// Preserved decorative brand glyph size, independent of terminal typography.
    public let brandDecorationSize: Double

    /// Preserved native header height, keeping the sidebar's placement stable.
    public let brandHeaderHeight: Double

    /// Preserved shell top inset beneath window chrome.
    public let shellTopInset: Double

    /// Preserved native spacing between the proxy folder icon and window title.
    public let titlebarContentGap: Double

    /// Preserved native build-badge content insets.
    public let titlebarBadgePadding: EdgeInsets

    /// Preserved native build-badge distance from the trailing window edge.
    public let titlebarTrailingInset: Double

    /// Gap between primary navigation controls, retained from the approved composition.
    public let primaryNavigationGap: Double

    /// Thickness of the active primary navigation underline.
    public let primaryNavigationIndicatorWidth: Double

    /// Main panel top inset beneath the brand header, measured from the reference crop.
    public let mainPanelTopInset: Double

    /// Native heading baseline correction for SF's different line-box leading.
    public let workspaceHeadingTopAdjustment: Double

    /// Gap above the primary navigation after native heading baseline alignment.
    public let primaryNavigationTopGap: Double

    /// Space below primary navigation labels and above their selection marker.
    public let primaryNavigationBottomGap: Double

    /// Gap between embedded primary navigation and terminal tabs, replacing window-titlebar padding.
    public let embeddedTerminalTopGap: Double

    /// Terminal tab strip height measured between its top and the terminal inset.
    public let terminalTabBarHeight: Double

    /// Additional space around the native terminal portal, measured against the reference ink bounds.
    public let terminalContentPadding: EdgeInsets

    /// Minimum sidebar width in points.
    public let sidebarMinimumWidth: Double

    /// Preferred sidebar fraction of the available window width.
    public let sidebarPreferredFraction: Double

    /// Maximum sidebar width in points.
    public let sidebarMaximumWidth: Double

    /// Card content padding in points.
    public let cardPadding: EdgeInsets

    /// Minimum workspace-card header height measured from the reference; rich metadata may grow taller.
    public let workspaceCardHeaderHeight: Double

    /// Preserved spacing between workspace-card header metadata and controls.
    public let workspaceCardHeaderGap: Double

    /// Preserved size of the active-AI indicator in the workspace-card header.
    public let workspaceCardActivitySize: Double

    /// Preserved stroke width of the active-AI indicator in the workspace-card header.
    public let workspaceCardActivityStroke: Double

    /// Gap within card content in points.
    public let cardContentGap: Double

    /// Gap between cards in points.
    public let cardGap: Double

    /// Panel content padding in points.
    public let panelPadding: EdgeInsets

    /// Standard icon size in points.
    public let iconSize: Double

    /// Small icon size in points.
    public let smallIconSize: Double

    /// Standard icon stroke width in points.
    public let iconStroke: Double

    /// Minimum flat-control hit target in points.
    public let minimumHitSize: Double

    /// Raised-control hit target in points.
    public let raisedHitSize: Double

    /// Additional invisible control hit-area expansion in points.
    public let invisibleHitExpansion: Double

    /// Hairline surface and selected terminal-tab edge thickness in points.
    public let hairlineWidth: Double

    /// Keyboard focus outline width in points.
    public let focusOutlineWidth: Double

    /// Keyboard focus outline offset from the card edge in points.
    public let focusOutlineOffset: Double

    /// Hovered-link underline thickness in points.
    public let linkUnderlineWidth: Double

    /// Leading square identifying the selected workspace, in points.
    public let selectedMarkerSize: Double

    /// Disabled workspace-card opacity.
    public let disabledOpacity: Double
}
