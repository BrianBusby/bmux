import AppKit
import SwiftUI
import Testing

@testable import BmuxAppKitSupportUI

@Suite struct MatteThemeTests {
    @Test(arguments: [ColorScheme.dark, .light])
    func intendedTextPairingsMeetNormalTextContrast(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        for foreground in [MatteColorRole.textPrimary, .textSecondary, .textTertiary, .link, .sage] {
            let ratio = try contrast(theme.color(foreground), theme.color(.card))
            #expect(ratio >= 4.5, "\(foreground) on card has contrast \(ratio)")
        }
        #expect(try contrast(theme.color(.terminalText), theme.color(.inset)) >= 4.5)
        for foreground in [MatteColorRole.success, .warning, .danger, .information] {
            #expect(try contrast(theme.color(foreground), theme.color(.panel)) >= 4.5)
        }
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func selectionAndFocusRemainDistinctAgainstAdjacentSurfaces(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        for surface in [MatteColorRole.base, .cardSelected, .cardSelectedHover] {
            #expect(try contrast(theme.color(.selectionRing), theme.color(surface)) >= 3)
            #expect(try contrast(theme.color(.focus), theme.color(surface)) >= 3)
        }
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func surfacesAndForegroundsStayOpaqueWhileWashesRemainTranslucent(scheme: ColorScheme) {
        let theme = MatteTheme(colorScheme: scheme)
        for role in MatteColorRole.allCases {
            let alpha = theme.color(role).alphaComponent
            switch role {
            case .edge, .hoverWash, .pressWash:
                #expect(alpha > 0 && alpha < 1)
            default:
                #expect(alpha == 1, "\(role) must not inherit wallpaper or material colors")
            }
        }
    }

    @Test @MainActor
    func dynamicColorsFollowEffectiveAppearanceWithoutRecreation() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        let highContrastDark = try #require(NSAppearance(named: .accessibilityHighContrastDarkAqua))
        let highContrastLight = try #require(NSAppearance(named: .accessibilityHighContrastAqua))
        for role in MatteColorRole.allCases {
            let dynamic = MatteTheme.dynamicColor(role)
            for (appearance, scheme) in [(dark, ColorScheme.dark), (light, .light), (highContrastDark, .dark), (highContrastLight, .light), (dark, .dark)] {
                var resolved: NSColor?
                appearance.performAsCurrentDrawingAppearance {
                    resolved = dynamic.usingColorSpace(.sRGB)
                }
                let actual = try #require(resolved)
                let expected = MatteTheme(colorScheme: scheme).color(role)
                #expect(actual == expected, "\(role) must follow effective appearance \(appearance.name)")
                #expect(MatteTheme(appearance: appearance).colorScheme == scheme)
            }
        }
    }

    @Test(arguments: [false, true])
    func reduceMotionSuppressesEveryTransitionAndLift(reduceMotion: Bool) {
        let theme = MatteTheme(colorScheme: .dark)
        let motion = theme.motion(reduceMotion: reduceMotion)
        #expect((motion.controlDuration == 0) == reduceMotion)
        #expect((motion.cardDuration == 0) == reduceMotion)
        for isHovered in [false, true] {
            for isSelected in [false, true] {
                for isPressed in [false, true] {
                    let lift = theme.cardLift(
                        isHovered: isHovered, isSelected: isSelected,
                        isPressed: isPressed, isEnabled: true, reduceMotion: reduceMotion
                    )
                    let eligible = isHovered && !isSelected && !isPressed && !reduceMotion
                    #expect((lift > 0) == eligible)
                    #expect(theme.cardLift(
                        isHovered: isHovered, isSelected: isSelected,
                        isPressed: isPressed, isEnabled: false, reduceMotion: reduceMotion
                    ) == 0)
                }
            }
        }
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func elevationLayersRetainRecessAndContactSemantics(scheme: ColorScheme) {
        let theme = MatteTheme(colorScheme: scheme)
        for role in [MatteShadowRole.terminalInset, .fieldInset] {
            #expect(theme.shadows(role).allSatisfy { $0.isInset })
        }
        for role in [MatteShadowRole.contactZero, .contactOne, .contactTwo, .contactThree] {
            let shadows = theme.shadows(role)
            #expect(shadows.allSatisfy { !$0.isInset && $0.offsetY > 0 && $0.blur > 0 })
        }
        #expect(theme.shadows(.selectedLit).count > theme.shadows(.lit).count)
        for role in MatteShadowRole.allCases {
            #expect(theme.shadows(role).allSatisfy { $0.color.alphaComponent > 0 && $0.blur >= 0 })
        }
    }

    private func contrast(_ first: NSColor, _ second: NSColor) throws -> Double {
        let lhs = try luminance(first)
        let rhs = try luminance(second)
        return (max(lhs, rhs) + 0.05) / (min(lhs, rhs) + 0.05)
    }

    private func luminance(_ color: NSColor) throws -> Double {
        let rgb = try #require(color.usingColorSpace(.sRGB))
        return 0.2126 * linearize(rgb.redComponent)
            + 0.7152 * linearize(rgb.greenComponent)
            + 0.0722 * linearize(rgb.blueComponent)
    }

    private func linearize(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
