import AppKit
import SwiftUI
import Testing

@testable import BmuxAppKitSupportUI

@Suite @MainActor
struct MatteSurfaceTests {
    @Test
    func selectedHoverRetainsSelectionAndDisabledIgnoresInteraction() {
        let selected = MatteSurfaceAppearance(role: .card, state: .init(isSelected: true, isHovered: true))
        #expect(selected.fill == .cardSelectedHover)
        #expect(selected.contour == .ring)
        #expect(selected.contact == .contactTwo)
        #expect(selected.ambient == .ambientTwo)
        let disabled = MatteSurfaceAppearance(
            role: .card, state: .init(isSelected: true, isHovered: true, isPressed: true, isEnabled: false)
        )
        let resting = MatteSurfaceAppearance(role: .card, state: .init())
        #expect(disabled.fill == .cardSelected)
        #expect(disabled.contour == .ring)
        #expect(disabled.contact == resting.contact)
        #expect(disabled.ambient == resting.ambient)
    }

    @Test
    func pressedCardKeepsOnlyRestingContactWhileOtherSurfacesIgnoreCardState() {
        let pressed = MatteSurfaceAppearance(role: .card, state: .init(isHovered: true, isPressed: true))
        #expect(pressed.contact == .contactOne)
        #expect(pressed.ambient == nil)
        for role in [MatteSurfaceRole.base, .panel, .inset, .overlay] {
            #expect(MatteSurfaceAppearance(role: role, state: .init()) == MatteSurfaceAppearance(
                role: role, state: .init(isSelected: true, isHovered: true, isPressed: true)
            ))
        }
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func renderedSurfacesKeepOpaqueInteriorsAndRequestedSize(scheme: ColorScheme) throws {
        for role in MatteSurfaceRole.allCases {
            let bitmap = try render(role: role, scheme: scheme, padding: 0)
            #expect(bitmap.pixelsWide == 120)
            #expect(bitmap.pixelsHigh == 80)
            let center = try #require(bitmap.colorAt(x: 60, y: 40))
            #expect(center.alphaComponent == 1)
            let expectedRole = MatteSurfaceAppearance(role: role, state: .init()).fill
            let reference = ImageRenderer(content: Color(nsColor: MatteTheme(colorScheme: scheme).color(expectedRole))
                .frame(width: 1, height: 1))
            let referenceImage = try #require(reference.cgImage)
            let expected = try #require(NSBitmapImageRep(cgImage: referenceImage).colorAt(x: 0, y: 0))
            #expect(distance(center, expected) < 0.02, "Interior must match an undecorated token fill for \(role)")
        }
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func raisedEdgesLightFromUpperLeftAndInsetIsRecessed(scheme: ColorScheme) throws {
        let card = try render(role: .card, scheme: scheme, padding: 0)
        let inset = try render(role: .inset, scheme: scheme, padding: 0)
        #expect(try brightness(card, x: 30, y: 0) > brightness(card, x: 89, y: 79))
        #expect(try brightness(inset, x: 60, y: 1) < brightness(inset, x: 60, y: 78))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func focusOutlineHasAVisibleGapAndBaseHasNoCastShadow(scheme: ColorScheme) throws {
        let focused = try render(role: .card, scheme: scheme, state: .init(isFocused: true), padding: 20)
        let unfocused = try render(role: .card, scheme: scheme, padding: 20)
        #expect(distance(try #require(focused.colorAt(x: 80, y: 17)),
                         try #require(unfocused.colorAt(x: 80, y: 17))) > 0.2)
        #expect(distance(try #require(focused.colorAt(x: 80, y: 19)),
                         try #require(unfocused.colorAt(x: 80, y: 19))) < 0.02)
        let base = try render(role: .base, scheme: scheme, padding: 20)
        #expect(try #require(base.colorAt(x: 80, y: 10)).alphaComponent == 0)
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func insetShadeSoftensTowardTheInterior(scheme: ColorScheme) throws {
        let image = try render(role: .inset, scheme: scheme, padding: 0)
        let interior = try brightness(image, x: 60, y: 20)
        let outerShade = try brightness(image, x: 60, y: 1)
        let innerShade = try brightness(image, x: 60, y: 3)
        #expect(abs(interior - innerShade) < abs(interior - outerShade) / 2)
    }

    @Test
    func disabledDecorationCompositesAsOneSurfaceAndLeavesContentUntouched() throws {
        let bitmap = try render(role: .card, scheme: .light, state: .init(isEnabled: false), padding: 0)
        let center = try #require(bitmap.colorAt(x: 60, y: 40))
        let nearEdge = try #require(bitmap.colorAt(x: 5, y: 40))
        #expect(abs(center.alphaComponent - nearEdge.alphaComponent) < 0.02)
        #expect(abs(center.alphaComponent - MatteTheme(colorScheme: .light).layout.disabledOpacity) < 0.02)
        let renderer = ImageRenderer(content: Color.red.frame(width: 120, height: 80)
            .matteSurface(.card, theme: MatteTheme(colorScheme: .light), state: .init(isEnabled: false)))
        let image = try #require(renderer.cgImage)
        #expect(try #require(NSBitmapImageRep(cgImage: image).colorAt(x: 60, y: 40)).alphaComponent == 1)
    }

    private func render(
        role: MatteSurfaceRole, scheme: ColorScheme, state: MatteSurfaceState = .init(), padding: Double
    ) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: Color.clear.frame(width: 120, height: 80)
            .matteSurface(role, theme: MatteTheme(colorScheme: scheme), state: state)
            .padding(padding))
        renderer.scale = 1
        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    private func brightness(_ image: NSBitmapImageRep, x: Int, y: Int) throws -> Double {
        let color = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return color.redComponent + color.greenComponent + color.blueComponent
    }

    private func distance(_ lhs: NSColor, _ rhs: NSColor) -> Double {
        let a = lhs.usingColorSpace(.sRGB)!
        let b = rhs.usingColorSpace(.sRGB)!
        return abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent)
            + abs(a.blueComponent - b.blueComponent)
    }
}
