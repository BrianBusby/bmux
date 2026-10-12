import AppKit
import BmuxAppKitSupportUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct MatteTitlebarContrastTests {
    @Test(arguments: [false, true])
    func foregroundUsesMatteSecondaryTextAndContrastsWithWindowBase(isDark: Bool) throws {
        let appearance = try #require(NSAppearance(named: isDark ? .darkAqua : .aqua))
        let theme = MatteTheme(appearance: appearance)
        var resolvedForeground: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolvedForeground = titlebarControlForegroundNSColor(opacity: 1)
                .usingColorSpace(.sRGB)
        }
        let foreground = try #require(resolvedForeground)
        let expected = try #require(theme.color(.textSecondary).usingColorSpace(.sRGB))

        #expect(abs(foreground.redComponent - expected.redComponent) < 0.001)
        #expect(abs(foreground.greenComponent - expected.greenComponent) < 0.001)
        #expect(abs(foreground.blueComponent - expected.blueComponent) < 0.001)
        #expect(foreground.alphaComponent == 1)
        #expect(bmuxContrastRatio(foreground: foreground, background: theme.color(.base)) >= 4.5)
    }
}
