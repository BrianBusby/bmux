public import SwiftUI
import AppKit

extension View {
    /// Applies native system typography from a semantic matte text role.
    /// - Parameters:
    ///   - role: The chrome text role; terminal preferences remain caller-owned.
    ///   - theme: Effective appearance tokens.
    /// - Returns: Content with the role's size, weight, tracking, and line spacing.
    public func matteTypography(_ role: MatteTypographyRole, theme: MatteTheme) -> some View {
        let metrics = theme.typography(role)
        let weight: Font.Weight = metrics.weight >= 750 ? .heavy : metrics.weight >= 700 ? .bold
            : metrics.weight >= 600 ? .semibold : metrics.weight >= 500 ? .medium : .regular
        let nativeWeight: NSFont.Weight = metrics.weight >= 750 ? .heavy : metrics.weight >= 700 ? .bold
            : metrics.weight >= 600 ? .semibold : metrics.weight >= 500 ? .medium : .regular
        let nativeFont = metrics.usesMonospacedFont
            ? NSFont.monospacedSystemFont(ofSize: metrics.pointSize, weight: nativeWeight)
            : NSFont.systemFont(ofSize: metrics.pointSize, weight: nativeWeight)
        // SwiftUI rounds ascent and descent separately when laying out native text.
        let nativeLineHeight = ceil(nativeFont.ascender) + ceil(-nativeFont.descender) + ceil(nativeFont.leading)
        let extraLineSpacing: Double
        if let lineHeightMultiple = metrics.lineHeightMultiple {
            extraLineSpacing = max(0, metrics.pointSize * lineHeightMultiple - nativeLineHeight)
        } else {
            extraLineSpacing = 0
        }
        return font(.system(size: metrics.pointSize, weight: weight,
                            design: metrics.usesMonospacedFont ? .monospaced : .default))
            .tracking(metrics.trackingEm * metrics.pointSize)
            .lineSpacing(extraLineSpacing)
    }
}
