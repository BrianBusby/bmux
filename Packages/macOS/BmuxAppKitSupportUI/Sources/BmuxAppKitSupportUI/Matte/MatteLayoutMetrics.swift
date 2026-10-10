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

    /// Minimum sidebar width in points.
    public let sidebarMinimumWidth: Double

    /// Preferred sidebar fraction of the available window width.
    public let sidebarPreferredFraction: Double

    /// Maximum sidebar width in points.
    public let sidebarMaximumWidth: Double

    /// Card content padding in points.
    public let cardPadding: EdgeInsets

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

    /// Keyboard focus outline width in points.
    public let focusOutlineWidth: Double

    /// Keyboard focus outline offset from the card edge in points.
    public let focusOutlineOffset: Double

    /// Hovered-link underline thickness in points.
    public let linkUnderlineWidth: Double

    /// Disabled workspace-card opacity.
    public let disabledOpacity: Double
}
