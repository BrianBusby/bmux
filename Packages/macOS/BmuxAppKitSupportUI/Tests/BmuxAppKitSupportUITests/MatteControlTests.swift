import AppKit
import SwiftUI
import Testing

@testable import BmuxAppKitSupportUI

@Suite @MainActor
struct MatteControlTests {
    @Test(arguments: [ColorScheme.dark, .light])
    func fieldsAreRecessedAndFlatControlsDoNotCastShadows(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        let field = try render(role: .field, theme: theme)
        let top = try #require(field.colorAt(x: 40, y: 21)?.usingColorSpace(.sRGB))
        let center = try #require(field.colorAt(x: 40, y: 38)?.usingColorSpace(.sRGB))
        #expect(brightness(top) < brightness(center))
        let flat = try render(role: .flat, theme: theme)
        #expect(try #require(flat.colorAt(x: 40, y: 38)) == #require(flat.colorAt(x: 1, y: 1)))
        let hover = try render(role: .flat, theme: theme, state: .init(isHovered: true))
        #expect(try #require(hover.colorAt(x: 40, y: 38)) != #require(hover.colorAt(x: 1, y: 1)))
        #expect(try #require(hover.colorAt(x: 40, y: 18)) == #require(hover.colorAt(x: 1, y: 1)))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func focusedFieldsDrawOutsideTheFieldWithoutChangingItsInterior(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        let resting = try render(role: .field, theme: theme)
        let focused = try render(role: .field, theme: theme, state: .init(isFocused: true))
        #expect(try #require(resting.colorAt(x: 40, y: 17)) == #require(resting.colorAt(x: 1, y: 1)))
        #expect(try #require(focused.colorAt(x: 40, y: 17)) != #require(focused.colorAt(x: 1, y: 1)))
        #expect(try #require(focused.colorAt(x: 40, y: 19)) == #require(focused.colorAt(x: 1, y: 1)))
        #expect(try #require(resting.colorAt(x: 40, y: 38)) == #require(focused.colorAt(x: 40, y: 38)))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func pressedRaisedControlDropsItsCastShadow(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        let resting = try render(role: .raised, theme: theme)
        let pressed = try render(role: .raised, theme: theme, state: .init(isPressed: true))
        #expect(try #require(resting.colorAt(x: 40, y: 57)) != #require(resting.colorAt(x: 1, y: 1)))
        #expect(try #require(pressed.colorAt(x: 40, y: 57)) == #require(pressed.colorAt(x: 1, y: 1)))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func disabledRaisedButtonsCompositeTheirLabelAndChromeOnce(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        let renderer = ImageRenderer(content: Button {} label: {
            Color.clear.frame(width: 40, height: 36)
        }
        .buttonStyle(MatteButtonStyle(theme: theme))
        .disabled(true)
        .padding(20))
        renderer.scale = 1
        let image = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        let center = try #require(image.colorAt(x: 40, y: 38))
        let nearEdge = try #require(image.colorAt(x: 23, y: 38))
        #expect(abs(center.alphaComponent - theme.layout.disabledOpacity) < 0.02)
        #expect(abs(center.alphaComponent - nearEdge.alphaComponent) < 0.02)
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func enclosingDisabledCardsCanOwnLinkOpacity(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        let renderer = ImageRenderer(content: Button {} label: {
            Color.black.frame(width: 40, height: 36)
        }
        .buttonStyle(MatteButtonStyle(.link, theme: theme, dimsWhenDisabled: false))
        .disabled(true)
        .opacity(theme.layout.disabledOpacity))
        let image = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        #expect(abs(try #require(image.colorAt(x: 20, y: 18)).alphaComponent - theme.layout.disabledOpacity) < 0.02)
    }

    @Test
    func multilineTitlesUseTheTokenBaselineRatherThanAddingItToNativeLeading() throws {
        let theme = MatteTheme(colorScheme: .light)
        func height(lines: Int) throws -> Double {
            let renderer = ImageRenderer(content: Text(Array(repeating: "Workspace title", count: lines)
                .joined(separator: "\n")).matteTypography(.cardTitle, theme: theme))
            renderer.scale = 10
            return Double(try #require(renderer.cgImage).height) / renderer.scale
        }
        let metrics = theme.typography(.cardTitle)
        let expectedBaseline = metrics.pointSize * (try #require(metrics.lineHeightMultiple))
        #expect(abs(try height(lines: 3) - height(lines: 2) - expectedBaseline) < 0.15)
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func selectedControlsRetainTheirRingAndTintThroughPressAndDisabling(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        let normal = try render(role: .raised, theme: theme)
        let selected = try render(role: .raised, theme: theme, state: .init(isSelected: true))
        let hovered = try render(role: .raised, theme: theme, state: .init(isSelected: true, isHovered: true))
        let pressed = try render(role: .raised, theme: theme, state: .init(isSelected: true, isHovered: true, isPressed: true))
        let disabled = try render(role: .raised, theme: theme, state: .init(
            isSelected: true, isHovered: true, isPressed: true, isEnabled: false))
        #expect(try #require(normal.colorAt(x: 40, y: 38)) != #require(selected.colorAt(x: 40, y: 38)))
        #expect(try #require(hovered.colorAt(x: 40, y: 38)) != #require(selected.colorAt(x: 40, y: 38)))
        for image in [pressed, disabled] {
            #expect(try #require(image.colorAt(x: 40, y: 38)) == #require(selected.colorAt(x: 40, y: 38)))
            #expect(try #require(image.colorAt(x: 19, y: 38)) == #require(selected.colorAt(x: 19, y: 38)))
        }
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func buttonStyleDrawsTheFocusStateOwnedByItsNativeButton(scheme: ColorScheme) throws {
        let theme = MatteTheme(colorScheme: scheme)
        func image(focused: Bool) throws -> NSBitmapImageRep {
            let renderer = ImageRenderer(content: Button {} label: {
                Color.clear.frame(width: 40, height: 36)
            }
            .buttonStyle(MatteButtonStyle(theme: theme))
            .environment(\.matteButtonIsFocused, focused)
            .padding(20)
            .background(Color(nsColor: theme.color(.base))))
            renderer.scale = 1
            return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        }
        let resting = try image(focused: false)
        let focused = try image(focused: true)
        #expect(try #require(resting.colorAt(x: 40, y: 17)) != #require(focused.colorAt(x: 40, y: 17)))
        #expect(try #require(resting.colorAt(x: 40, y: 38)) == #require(focused.colorAt(x: 40, y: 38)))
    }

    private func render(role: MatteControlRole, theme: MatteTheme,
                        state: MatteSurfaceState = .init()) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: MatteControlDecoration(role: role, theme: theme, state: state)
            .frame(width: 40, height: 36).padding(20)
            .background(Color(nsColor: theme.color(.base))))
        renderer.scale = 1
        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    private func brightness(_ color: NSColor) -> Double {
        color.redComponent + color.greenComponent + color.blueComponent
    }
}
