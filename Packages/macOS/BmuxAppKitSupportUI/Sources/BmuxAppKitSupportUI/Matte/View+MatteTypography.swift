public import SwiftUI
import AppKit

extension View {
    /// Applies native system typography from a semantic matte text role.
    /// - Parameters:
    ///   - role: The chrome text role; terminal preferences remain caller-owned.
    ///   - theme: Effective appearance tokens.
    ///   - pointSize: Optional size resolved by the caller's existing font-magnification policy.
    /// - Returns: Content with the role's size, weight, tracking, and line spacing.
    public func matteTypography(_ role: MatteTypographyRole, theme: MatteTheme, pointSize: Double? = nil) -> some View {
        let metrics = theme.typography(role)
        let resolvedPointSize = pointSize ?? metrics.pointSize
        let stops: [(Double, NSFont.Weight)] = [(400, .regular), (500, .medium), (600, .semibold), (700, .bold), (800, .heavy)]
        let lower = stops.last(where: { $0.0 <= metrics.weight }) ?? stops[0]
        let upper = stops.first(where: { $0.0 >= metrics.weight }) ?? stops[stops.count - 1]
        let fraction = upper.0 == lower.0 ? 0 : (metrics.weight - lower.0) / (upper.0 - lower.0)
        let nativeWeight = NSFont.Weight(rawValue: lower.1.rawValue + CGFloat(fraction) * (upper.1.rawValue - lower.1.rawValue))
        let nativeFont = metrics.usesMonospacedFont
            ? NSFont.monospacedSystemFont(ofSize: resolvedPointSize, weight: nativeWeight)
            : NSFont.systemFont(ofSize: resolvedPointSize, weight: nativeWeight)
        // SwiftUI rounds ascent and descent separately when laying out native text.
        let nativeLineHeight = ceil(nativeFont.ascender) + ceil(-nativeFont.descender) + ceil(nativeFont.leading)
        let extraLineSpacing: Double
        if let lineHeightMultiple = metrics.lineHeightMultiple {
            extraLineSpacing = max(0, resolvedPointSize * lineHeightMultiple - nativeLineHeight)
        } else {
            extraLineSpacing = 0
        }
        return font(Font(nativeFont))
            .tracking(metrics.trackingEm * resolvedPointSize)
            .lineSpacing(extraLineSpacing)
    }
}
